use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use sphinx_client::{
    gas::live::{
        assert_block, assert_current_module, estimate_network, qualify_final_network, LiveGasReport,
    },
    merkle::SphinxMerkleTree,
    types::{ActionType, NetworkConfig, Operation},
};
use std::io::{self, Read};

const REVISION: &str = "9a31bf8fb9bc464243d3252c69fcdc1f6460fe3c";
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
    mode: Mode,
    networks: Vec<Network>,
    tree: Option<SphinxMerkleTree>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
struct Network {
    rpc_env: String,
    expected_block_hash: String,
    config: NetworkConfig,
    report: Option<LiveGasReport>,
}

#[derive(Serialize)]
struct ResultEntry {
    config: NetworkConfig,
    report: LiveGasReport,
}

fn validate(request: &Request) -> Result<(), &'static str> {
    if request.schema_version != 1 || request.client_revision != REVISION {
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
        if config.action_inputs.len() != 2 {
            return Err("resolver qualification requires exactly two ordered actions");
        }
        for (index, action) in config.action_inputs.iter().enumerate() {
            if action.index != index as u64 + 1
                || !action.value.is_zero()
                || !action.require_success
                || !matches!(action.operation, Operation::DelegateCall)
                || !matches!(action.action_type, ActionType::Call)
                || action.deployed_address.is_some()
                || action.init_code.is_some()
                || action.tx_data.is_empty()
                || action.gas.is_zero()
            {
                return Err("unexpected resolver action envelope");
            }
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
        assert_block(&rpc, config.block_number, hash)
            .await
            .map_err(|e| format!("{e:#}"))?;
        let report = match request.mode {
            Mode::Estimate => estimate_network(&mut config, &rpc, false)
                .await
                .map_err(|e| format!("{e:#}"))?,
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
            serde_json::json!({"schemaVersion": 1, "clientRevision": REVISION,
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
            "clientRevision": REVISION, "results": results})
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
        serde_json::from_value(serde_json::json!({"schemaVersion":1,"clientRevision":REVISION,
            "mode":"estimate","networks":[{"rpcEnv":"RPC_ETHEREUM_SEPOLIA",
            "expectedBlockHash":format!("0x{}", "11".repeat(32)), "config":{
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
        assert_eq!(
            validate(&request),
            Err("unexpected resolver action envelope")
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
        let request = serde_json::json!({"schemaVersion":1,"clientRevision":REVISION,
            "mode":"estimate","networks":[],"rpcUrl":"https://secret.example"});
        assert!(serde_json::from_value::<Request>(request).is_err());
        let request = serde_json::json!({"schemaVersion":1,"clientRevision":REVISION,
            "mode":"broadcast","networks":[]});
        assert!(serde_json::from_value::<Request>(request).is_err());
    }

    #[test]
    fn rejects_empty_profiles_wrong_revision_and_missing_final_proofs() {
        let mut request: Request = serde_json::from_value(serde_json::json!({
            "schemaVersion":1,"clientRevision":REVISION,"mode":"estimate","networks":[]
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
