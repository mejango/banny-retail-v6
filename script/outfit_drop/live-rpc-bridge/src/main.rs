use alloy::providers::{Provider, RootProvider};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use sphinx_client::{
    gas::live::{
        assert_block, assert_current_module, qualify_final_network, ActionGasBudget, LiveGasReport,
    },
    merkle::SphinxMerkleTree,
    types::{ActionType, NetworkConfig, Operation},
};
use std::io::{self, Read};

const REVISION: &str = "afcdc4e3eb1eeccea5d9c47977ec4ca381b4bbce";
const VERIFIER_REVISION: &str = "9a31bf8fb9bc464243d3252c69fcdc1f6460fe3c";
const RPC_NETWORKS: &[(&str, u64)] = &[
    ("RPC_ETHEREUM_MAINNET", 1),
    ("RPC_OPTIMISM_MAINNET", 10),
    ("RPC_BASE_MAINNET", 8453),
    ("RPC_ARBITRUM_MAINNET", 42161),
    ("RPC_ETHEREUM_SEPOLIA", 11155111),
    ("RPC_OPTIMISM_SEPOLIA", 11155420),
    ("RPC_BASE_SEPOLIA", 84532),
    ("RPC_ARBITRUM_SEPOLIA", 421614),
];

#[derive(Deserialize)]
#[serde(rename_all = "lowercase")]
enum Mode {
    Estimate,
    Final,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
struct Request {
    schema_version: u8,
    client_revision: String,
    verifier_revision: String,
    mode: Mode,
    networks: Vec<Network>,
    tree: Option<SphinxMerkleTree>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
struct Network {
    rpc_env: String,
    expected_block_hash: String,
    expected_block_timestamp: u64,
    config: NetworkConfig,
    report: Option<LiveGasReport>,
}

#[derive(Serialize)]
struct ResultEntry {
    config: NetworkConfig,
    report: LiveGasReport,
}

fn validate(request: &Request) -> Result<(), &'static str> {
    if request.schema_version != 1
        || request.client_revision != REVISION
        || request.verifier_revision != VERIFIER_REVISION
    {
        return Err("unsupported schema or client revision");
    }
    if request.networks.is_empty() || request.networks.len() > 4 {
        return Err("expected one bounded network profile");
    }
    match request.mode {
        Mode::Estimate
            if request.tree.is_some() || request.networks.iter().any(|n| n.report.is_some()) =>
        {
            return Err("estimate must not include a tree or reports")
        }
        Mode::Final
            if request.tree.is_none() || request.networks.iter().any(|n| n.report.is_none()) =>
        {
            return Err("final needs the exact SDK tree and initial reports")
        }
        _ => (),
    }
    let mut chains = std::collections::BTreeSet::new();
    for network in &request.networks {
        let chain = RPC_NETWORKS
            .iter()
            .find(|(name, _)| *name == network.rpc_env)
            .ok_or("unsupported RPC environment variable")?
            .1;
        let config = &network.config;
        if config.chain_id != chain || !chains.insert(chain) || config.arbitrary_chain {
            return Err("chain identity differs, repeats or is unbound");
        }
        if !config.initial_state.is_safe_deployed
            || !config.initial_state.is_module_deployed
            || config.initial_state.is_executing
            || !config.is_system_deployed
        {
            return Err("live qualification needs existing idle Safe and module");
        }
        if config.action_inputs.is_empty() {
            return Err("qualification requires nonempty ordered actions");
        }
        for (index, action) in config.action_inputs.iter().enumerate() {
            if action.index != index as u64 + 1
                || !action.value.is_zero()
                || !action.require_success
                || !matches!(action.operation, Operation::Call | Operation::DelegateCall)
                || !matches!(action.action_type, ActionType::Call)
                || action.deployed_address.is_some()
                || action.init_code.is_some()
                || action.tx_data.is_empty()
                || action.gas.is_zero()
            {
                return Err("unexpected action envelope");
            }
        }
        if network.expected_block_timestamp == 0 {
            return Err("invalid finalized block timestamp");
        }
        if network.expected_block_hash.len() != 66
            || !network.expected_block_hash.starts_with("0x")
            || !network.expected_block_hash[2..]
                .bytes()
                .all(|b| b.is_ascii_hexdigit())
        {
            return Err("invalid finalized block hash");
        }
    }
    Ok(())
}

fn adopt_sizing(config: &mut NetworkConfig, sized: &NetworkConfig) -> Result<(), String> {
    // Current sizing proposes gas; the existing locally verified allowance is
    // a replay floor. Only the later exact-root live proof authenticates it.
    let mut candidate = config.clone();
    for (action, returned) in candidate.action_inputs.iter_mut().zip(&sized.action_inputs) {
        if returned.gas.is_zero() {
            return Err("current sizing returned zero signed gas".into());
        }
        action.gas = action.gas.max(returned.gas);
    }
    let mut envelope = sized.clone();
    for (action, frozen) in envelope
        .action_inputs
        .iter_mut()
        .zip(&candidate.action_inputs)
    {
        action.gas = frozen.gas;
    }
    if serde_json::to_value(&candidate).map_err(|_| "could not encode sized config")?
        != serde_json::to_value(&envelope).map_err(|_| "could not encode sizing result")?
    {
        return Err("current sizing changed fields other than signed gas".into());
    }
    *config = candidate;
    Ok(())
}

fn validate_header(
    header: &serde_json::Value,
    block: alloy::primitives::U256,
    hash: alloy::primitives::B256,
    timestamp: u64,
) -> Result<(), String> {
    let quantity = |field: &str| -> Result<alloy::primitives::U256, String> {
        header
            .get(field)
            .and_then(serde_json::Value::as_str)
            .and_then(|value| value.parse().ok())
            .ok_or_else(|| "invalid pinned header identity".into())
    };
    let actual_hash = header
        .get("hash")
        .and_then(serde_json::Value::as_str)
        .and_then(|value| value.parse::<alloy::primitives::B256>().ok())
        .ok_or("invalid pinned header identity")?;
    if quantity("number")? != block
        || actual_hash != hash
        || quantity("timestamp")? != alloy::primitives::U256::from(timestamp)
    {
        return Err("pinned header number, hash or timestamp changed".into());
    }
    Ok(())
}

async fn assert_header(
    rpc: &str,
    block: alloy::primitives::U256,
    hash: alloy::primitives::B256,
    timestamp: u64,
) -> Result<(), String> {
    let provider: RootProvider =
        RootProvider::new_http(rpc.parse().map_err(|_| "invalid RPC endpoint")?);
    let header: Option<serde_json::Value> = tokio::time::timeout(
        std::time::Duration::from_secs(45),
        provider.raw_request(
            "eth_getBlockByNumber".into(),
            (format!("{block:#x}"), false),
        ),
    )
    .await
    .map_err(|_| "pinned header read timed out")?
    .map_err(|_| "pinned header read failed; provider diagnostics suppressed")?;
    validate_header(
        &header.ok_or("pinned header unavailable")?,
        block,
        hash,
        timestamp,
    )
}

fn estimate_report(
    config: &NetworkConfig,
    hash: alloy::primitives::B256,
    timestamp: u64,
) -> Result<LiveGasReport, String> {
    let outer_cap: u64 = config
        .block_gas_limit
        .try_into()
        .map_err(|_| "invalid reviewed outer cap")?;
    Ok(LiveGasReport {
        chain_id: config.chain_id.to_string(), block_number: config.block_number.try_into().map_err(|_| "invalid block number")?,
        block_hash: hash, base_timestamp: timestamp, simulated_block_interval_seconds: 1,
        safe: config.safe_address, module: config.module_address, executor: config.executor_address,
        authorization_scope: format!("current sizing {REVISION} with existing local replay floor; exact-root verifier {VERIFIER_REVISION}; synthetic approval only, no owner signatures or approval gas qualification"),
        execution_shape: "one execution leaf per transaction; exact outer budgets required".into(),
        final_merkle_root: None,
        actions: config.action_inputs.iter().map(|action| Ok(ActionGasBudget {
            index: action.index, signed_inner_gas: action.gas.try_into().map_err(|_| "invalid signed gas")?,
            // Unqualified seed only. The retained exact-root verifier owns all
            // bounded outer growth and authenticates the final transaction gas.
            outer_gas: {
                let seed: u64 = action.gas.try_into().map_err(|_| "invalid signed gas")?;
                if seed == 0 || seed > outer_cap { return Err("outer seed outside reviewed cap".into()); }
                seed
            }, calldata_hash: Default::default(), initial_probe_attempts: 0, final_proof_attempts: 0,
        })).collect::<Result<_, String>>()?,
    })
}

async fn run(request: Request) -> Result<Vec<ResultEntry>, String> {
    validate(&request).map_err(str::to_owned)?;
    let mut results = Vec::new();
    for network in request.networks {
        let rpc = std::env::var(&network.rpc_env)
            .map_err(|_| "required RPC environment variable is missing")?;
        if !(rpc.starts_with("https://") || rpc.starts_with("http://"))
            || rpc.chars().any(char::is_whitespace)
        {
            return Err("RPC endpoint must use HTTP or HTTPS".into());
        }
        let mut config = network.config;
        let hash = network
            .expected_block_hash
            .parse()
            .map_err(|_| "invalid finalized block hash")?;
        assert_header(
            &rpc,
            config.block_number,
            hash,
            network.expected_block_timestamp,
        )
        .await?;
        let report = match request.mode {
            Mode::Estimate => {
                // Current upstream owns sizing. The retained dependency owns only
                // independent exact-root qualification, never its older gas search.
                let mut current: sphinx_current::types::NetworkConfig = serde_json::from_value(
                    serde_json::to_value(&config).map_err(|_| "could not encode sizing config")?,
                )
                .map_err(|_| "incompatible current sizing config")?;
                sphinx_current::gas::estimate_gas_for_network(&mut current, &rpc)
                    .await
                    .map_err(|_| {
                        "current client gas sizing failed; provider diagnostics suppressed"
                    })?;
                let sized: NetworkConfig = serde_json::from_value(
                    serde_json::to_value(current).map_err(|_| "could not encode sizing result")?,
                )
                .map_err(|_| "incompatible current sizing result")?;
                adopt_sizing(&mut config, &sized)?;
                estimate_report(&config, hash, network.expected_block_timestamp)?
            }
            Mode::Final => {
                let mut report = network.report.expect("validated report");
                qualify_final_network(
                    &config,
                    &rpc,
                    request.tree.as_ref().expect("validated tree"),
                    &mut report,
                )
                .await
                .map_err(|e| format!("{e:#}"))?;
                assert_current_module(&config, &rpc)
                    .await
                    .map_err(|e| format!("{e:#}"))?;
                report
            }
        };
        assert_block(&rpc, config.block_number, hash)
            .await
            .map_err(|e| format!("{e:#}"))?;
        results.push(ResultEntry { config, report });
    }
    Ok(results)
}

#[tokio::main]
async fn main() {
    let args: Vec<_> = std::env::args().skip(1).collect();
    if args == ["--version"] {
        println!(
            "{}",
            serde_json::json!({"schemaVersion": 1, "clientRevision": REVISION, "verifierRevision": VERIFIER_REVISION,
            "bridgeVersion": env!("CARGO_PKG_VERSION"), "compiledSourceSha256": {
                "Cargo.toml": format!("{:x}", Sha256::digest(include_bytes!("../Cargo.toml"))),
                "Cargo.lock": format!("{:x}", Sha256::digest(include_bytes!("../Cargo.lock"))),
                "src/main.rs": format!("{:x}", Sha256::digest(include_bytes!("main.rs"))),
            }})
        );
        return;
    }
    let outcome = async {
        if !args.is_empty() {
            return Err("unexpected bridge arguments".to_owned());
        }
        let mut input = String::new();
        io::stdin()
            .take(16 * 1024 * 1024 + 1)
            .read_to_string(&mut input)
            .map_err(|_| "could not read bridge request")?;
        if input.len() > 16 * 1024 * 1024 {
            return Err("bridge request exceeds limit".into());
        }
        let request = serde_json::from_str(&input).map_err(|_| "invalid bridge request schema")?;
        run(request).await
    }
    .await;
    match outcome {
        Ok(results) => println!(
            "{}",
            serde_json::json!({"schemaVersion": 1,
            "clientRevision": REVISION, "verifierRevision": VERIFIER_REVISION, "results": results})
        ),
        Err(error) => {
            eprintln!("Live RPC qualification failed: {error}");
            std::process::exit(1);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exact_sdk_wire_tree_matches_pinned_library_encoding_and_proofs() {
        use sphinx_client::{
            merkle::{leaf_hash, make_sphinx_merkle_tree, verify_proof},
            types::ChainDeploymentData,
        };

        // Generated by the installed Node SDK, not the implementation under test.
        let request: Request =
            serde_json::from_str(include_str!("../tests/sdk-wire.json")).unwrap();
        validate(&request).unwrap();
        let deployments: Vec<ChainDeploymentData> = request
            .networks
            .iter()
            .map(|network| Option::<ChainDeploymentData>::from(&network.config).unwrap())
            .collect();
        let actual = make_sphinx_merkle_tree(&deployments);
        let sdk = request.tree.unwrap();
        assert_eq!(actual.root, sdk.root);
        assert_eq!(
            actual.leaves_with_proofs.len(),
            sdk.leaves_with_proofs.len()
        );
        for expected in &sdk.leaves_with_proofs {
            let matched: Vec<_> = actual
                .leaves_with_proofs
                .iter()
                .filter(|entry| {
                    entry.leaf.chain_id == expected.leaf.chain_id
                        && entry.leaf.index == expected.leaf.index
                })
                .collect();
            assert_eq!(matched.len(), 1);
            assert_eq!(matched[0].leaf, expected.leaf);
            assert_eq!(matched[0].proof, expected.proof);
            assert!(verify_proof(
                sdk.root,
                leaf_hash(&expected.leaf),
                &expected.proof
            ));
            assert!(verify_proof(
                actual.root,
                leaf_hash(&matched[0].leaf),
                &matched[0].proof
            ));
        }
    }

    fn fixture() -> Request {
        let action = |index| {
            serde_json::json!({"index":index,
            "to":"0x1111111111111111111111111111111111111111","value":"0x0",
            "gas":"0x989680","tx_data":"0x1234","operation":"DelegateCall",
            "require_success":true,"action_type":"Call","deployed_address":null,"init_code":null})
        };
        serde_json::from_value(serde_json::json!({"schemaVersion":1,"clientRevision":REVISION,"verifierRevision":VERIFIER_REVISION,
            "mode":"estimate","networks":[{"rpcEnv":"RPC_ETHEREUM_SEPOLIA",
            "expectedBlockHash":format!("0x{}", "11".repeat(32)), "expectedBlockTimestamp":1791294816, "config":{
                "safe_address":"0x1111111111111111111111111111111111111111",
                "module_address":"0x2222222222222222222222222222222222222222",
                "executor_address":"0x3333333333333333333333333333333333333333",
                "safe_init_data":"0x","nonce":"0x7","chain_id":"0xaa36a7",
                "block_gas_limit":"0x1c9c380","block_number":"0xb5ae9e",
                "new_config":{"project_name":"banny-core","org_id":"test","owners":[],
                    "threshold":"0x1","salt_nonce":"0x0","mainnets":[],"testnets":[]},
                "initial_state":{"is_safe_deployed":true,"is_module_deployed":true,"is_executing":false},
                "is_system_deployed":true,"action_inputs":[action(1),action(2)],
                "arbitrary_chain":false,"libraries":[],"git_commit":null
            }}]})).unwrap()
    }

    #[test]
    fn pinned_header_authenticates_timestamp_number_and_hash() {
        let block = alloy::primitives::U256::from(42u64);
        let hash = alloy::primitives::B256::repeat_byte(0x11);
        let header =
            serde_json::json!({"number":"0x2a","hash":format!("{hash:#x}"),"timestamp":"0x64"});
        assert!(validate_header(&header, block, hash, 100).is_ok());
        assert!(validate_header(&header, block, hash, 101).is_err());
        for (field, wrong) in [("number", "0x2b"), ("timestamp", "0x65"), ("hash", "0x00")] {
            let mut changed = header.clone();
            changed[field] = wrong.into();
            assert!(validate_header(&changed, block, hash, 100).is_err());
            changed.as_object_mut().unwrap().remove(field);
            assert!(validate_header(&changed, block, hash, 100).is_err());
        }
    }

    #[test]
    fn current_sizing_retains_local_floor_and_rejects_payload_drift() {
        let request = fixture();
        let original = request.networks[0].config.clone();
        // Both client releases serialize the same canonical action envelope.
        let current: sphinx_current::types::NetworkConfig =
            serde_json::from_value(serde_json::to_value(&original).unwrap()).unwrap();
        assert_eq!(
            serde_json::to_value(current).unwrap(),
            serde_json::to_value(&original).unwrap()
        );
        let mut sized = original.clone();
        sized.action_inputs[0].gas = alloy::primitives::U256::from(100_000u64);
        sized.action_inputs[1].gas = alloy::primitives::U256::from(12_000_000u64);
        let mut accepted = original.clone();
        adopt_sizing(&mut accepted, &sized).unwrap();
        assert_eq!(accepted.action_inputs[0].gas, original.action_inputs[0].gas);
        assert_eq!(accepted.action_inputs[1].gas, sized.action_inputs[1].gas);
        let report = estimate_report(&accepted, Default::default(), 1791294816).unwrap();
        assert!(report.authorization_scope.contains(REVISION));
        assert!(report.authorization_scope.contains(VERIFIER_REVISION));
        assert!(report
            .authorization_scope
            .contains("existing local replay floor"));
        assert!(report.final_merkle_root.is_none());
        assert!(report
            .actions
            .iter()
            .all(|a| a.initial_probe_attempts == 0 && a.final_proof_attempts == 0));
        assert!(report
            .actions
            .iter()
            .all(|a| a.outer_gas == a.signed_inner_gas));
        let mut capped = accepted.clone();
        capped.block_gas_limit = alloy::primitives::U256::from(1u64);
        assert!(estimate_report(&capped, Default::default(), 1791294816).is_err());
        capped = accepted.clone();
        capped.action_inputs[0].gas = Default::default();
        assert!(estimate_report(&capped, Default::default(), 1791294816).is_err());
        sized.action_inputs[0].value = alloy::primitives::U256::from(1u64);
        let before = serde_json::to_value(&accepted).unwrap();
        assert!(adopt_sizing(&mut accepted, &sized).is_err());
        assert_eq!(serde_json::to_value(&accepted).unwrap(), before);
        sized = original.clone();
        sized.action_inputs.pop();
        assert!(adopt_sizing(&mut accepted, &sized).is_err());
    }

    #[test]
    fn preserves_typed_envelopes_and_rejects_chain_or_action_drift() {
        let mut request = fixture();
        assert_eq!(validate(&request), Ok(()));
        let roundtrip: NetworkConfig =
            serde_json::from_value(serde_json::to_value(&request.networks[0].config).unwrap())
                .unwrap();
        assert_eq!(
            roundtrip.action_inputs[1].tx_data,
            request.networks[0].config.action_inputs[1].tx_data
        );
        request.networks[0].config.action_inputs[1].operation = Operation::Call;
        let mut third = request.networks[0].config.action_inputs[0].clone();
        third.index = 3;
        request.networks[0].config.action_inputs.push(third);
        assert_eq!(validate(&request), Ok(()));
        // The transport preserves mixed setup/migration operations, while
        // ordered canonical envelopes and zero value remain mandatory.
        let accepted = request.networks[0].config.clone();
        for changed in ["index", "value", "require_success", "gas", "tx_data"] {
            let mut candidate = fixture();
            candidate.networks[0].config = accepted.clone();
            let action = &mut candidate.networks[0].config.action_inputs[2];
            match changed {
                "index" => action.index = 2,
                "value" => action.value = alloy::primitives::U256::from(1u64),
                "require_success" => action.require_success = false,
                "gas" => action.gas = Default::default(),
                _ => action.tx_data = Default::default(),
            }
            assert_eq!(validate(&candidate), Err("unexpected action envelope"));
        }
        request.networks[0].config.action_inputs.clear();
        assert_eq!(
            validate(&request),
            Err("qualification requires nonempty ordered actions")
        );
        request = fixture();
        request.networks[0].rpc_env = "RPC_BASE_SEPOLIA".into();
        assert_eq!(
            validate(&request),
            Err("chain identity differs, repeats or is unbound")
        );
        request = fixture();
        request.mode = Mode::Final;
        assert_eq!(
            validate(&request),
            Err("final needs the exact SDK tree and initial reports")
        );
    }

    #[test]
    fn rejects_extra_fields_and_unknown_modes_without_echoing_input() {
        let request = serde_json::json!({"schemaVersion":1,"clientRevision":REVISION,"verifierRevision":VERIFIER_REVISION,
            "mode":"estimate","networks":[],"rpcUrl":"https://secret.example"});
        assert!(serde_json::from_value::<Request>(request).is_err());
        let request = serde_json::json!({"schemaVersion":1,"clientRevision":REVISION,"verifierRevision":VERIFIER_REVISION,
            "mode":"broadcast","networks":[]});
        assert!(serde_json::from_value::<Request>(request).is_err());
    }

    #[test]
    fn rejects_empty_profiles_wrong_revision_and_missing_final_proofs() {
        let mut request: Request = serde_json::from_value(serde_json::json!({
            "schemaVersion":1,"clientRevision":REVISION,"verifierRevision":VERIFIER_REVISION,"mode":"estimate","networks":[]
        }))
        .unwrap();
        assert_eq!(
            validate(&request),
            Err("expected one bounded network profile")
        );
        request.client_revision = "latest".into();
        assert_eq!(
            validate(&request),
            Err("unsupported schema or client revision")
        );
    }
}
