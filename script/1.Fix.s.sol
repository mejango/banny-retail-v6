// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JB721TierConfig} from "@bananapus/721-hook-v6/src/structs/JB721TierConfig.sol";
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";

import "./helpers/BannyverseDeploymentLib.sol";
import "@rev-net/core-v6/script/helpers/RevnetCoreDeploymentLib.sol";
import "@bananapus/core-v6/script/helpers/CoreDeploymentLib.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import {Sphinx} from "@sphinx-labs/contracts/SphinxPlugin.sol";
import {Script} from "forge-std/Script.sol";

import {Banny721TokenUriResolver} from "./../src/Banny721TokenUriResolver.sol";

contract Drop1Script is Script, Sphinx {
    /// @notice tracks the deployment of the revnet contracts for the chain we are deploying to.
    RevnetCoreDeployment revnet;
    /// @notice tracks the deployment of the bannyverse contracts for the chain we are deploying to.
    BannyverseDeployment bannyverse;
    /// @notice tracks the deployment of the core contracts for the chain we are deploying to.
    CoreDeployment core;

    JB721TiersHook hook;

    bytes32 RESOLVER_SALT = "_BAN_RESOLVER__";
    address OPERATOR;
    address TRUSTED_FORWARDER;

    function configureSphinx() public override {
        // TODO: Update to contain revnet devs.
        sphinxConfig.projectName = "banny-core-v6";
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "base_sepolia", "arbitrum_sepolia"];
    }

    function run() public {
        // Get the operator address.
        OPERATOR = safeAddress();

        // Get the deployment addresses for the nana CORE for this chain.
        // We want to do this outside of the `sphinx` modifier.
        core = CoreDeploymentLib.getDeployment(
            vm.envOr("NANA_CORE_DEPLOYMENT_PATH", string("node_modules/@bananapus/core-v6/deployments/"))
        );

        TRUSTED_FORWARDER = core.controller.trustedForwarder();

        // Get the deployment addresses for the revnet contracts for this chain.
        revnet = RevnetCoreDeploymentLib.getDeployment(
            vm.envOr("REVNET_CORE_DEPLOYMENT_PATH", string("node_modules/@rev-net/core-v6/deployments/"))
        );

        // Get the deployment addresses for the 721 hook contracts for this chain.
        bannyverse =
            BannyverseDeploymentLib.getDeployment(vm.envOr("BANNYVERSE_CORE_DEPLOYMENT_PATH", string("deployments/")));

        // Get the hook address by using the deployer.
        hook = JB721TiersHook(address(revnet.basic_deployer.tiered721HookOf(bannyverse.revnetId)));
        deploy();
    }

    function deploy() public sphinx {
        string[] memory names = new string[](47);
        bytes32[] memory svgHashes = new bytes32[](47);

        // Deploy the Banny URI Resolver.
        Banny721TokenUriResolver resolver;

        string memory _BANNY_BODY =
            '<g class="a1"><path d="M173 53h4v17h-4z"/></g><g class="a2"><path d="M167 57h3v10h-3z"/><path d="M169 53h4v17h-4z"/></g><g class="a3"><path d="M167 53h3v4h-3z"/><path d="M163 57h4v10h-4z"/><path d="M167 67h3v3h-3z"/></g><g class="b1"><path d="M213 253h-3v-3-3h-3v-7-3h-4v-10h-3v-7-7-3h-3v-73h-4v-10h-3v-10h-3v-7h-4v-7h-3v-3h-3v-3h-4v10h4v10h3v10h3v3h4v7 3 70 3h3v7h3v20h4v7h3v3h3v3h4v4h3v3h3v-3-4z"/><path d="M253 307v-4h-3v-3h-3v-3h-4v-4h-3v-3h-3v-3h-4v-4h-3v-3h-3v-3h-4v-4h-3v-6h-3v-7h-4v17h4v3h3v3h3 4v4h3v3h3v3h4v4h3v3h3v3h4v4h3v3h3v3h4v-6h-4z"/></g><g class="b2"><path d="M250 310v-3h-3v-4h-4v-3h-3v-3h-3v-4h-4v-3h-3v-3h-3v-4h-7v-3h-3v-3h-4v-17h-3v-3h-3v-4h-4v-3h-3v-3h-3v-7h-4v-20h-3v-7h-3v-73-3-7h-4v-3h-3v-10h-3v-10h-4V70h-3v-3l-3 100 3-100v40h-3v10h-4v6h-3v14h-3v3 13h-4v44h4v16h3v14h3v13h4v10h3v7h3v3h4v3h3v4h3v3h4v3h3v4h3v3h4v3h3v7h7v7h6v3h7v3h7v4h13v3h3v3h10v-3h-3zm-103-87v-16h3v-10h-3v6h-4v17h-3v10h3v-7h4z"/><path d="M143 230h4v7h-4zm4 10h3v3h-3zm3 7h3v3h-3zm3 6h4v4h-4z"/><path d="M163 257h-6v3h3v3h3v4h4v-4-3h-4v-3z"/></g><g class="b3"><path d="M143 197v6h4v-6h6v-44h4v-16h3v-14h3v-6h4v-10h3V97h-7v6h-3v4h-3v3h-4v3h-3v4 3h-3v3 4h-4v10h-3v16 4h-3v46h3v-6h3z"/><path d="M140 203h3v17h-3z"/><path d="M137 220h3v10h-3z"/><path d="M153 250h-3v-7h-3v-6h-4v-7h-3v10h3v7h4v6h3v4h3v-7zm-3 10h3v7h-3z"/><path d="M147 257h3v3h-3zm6 0h4v3h-4z"/><path d="M160 263v-3h-3v3 7h6v-7h-3zm-10-56v16h-3v7h3v10h3v7h4v6h6v4h7v-4-3h-3v-10h-4v-13h-3v-14h-3v-16h-4v10h-3z"/><path d="M243 313v-3h-3v-3h-10-3v-4h-7v-3h-7v-3h-6v-7h-7v-7h-3v-3h-4v-3h-3v-4h-3v-3h-4v-3h-3v-4h-3v-3h-4v-3h-3v10h-3v3h-4v3h-3v7h3v7h4v6h3v5h4v3h6v3h3v3h4 3v3h3 4v3h3 3v4h10v3h7 7 3v3h10 3v-3h10v-3h4v-4h-14z"/></g><g class="b4"><path d="M183 130h4v7h-4z"/><path d="M180 127h3v3h-3zm-27-4h4v7h-4z"/><path d="M157 117h3v6h-3z"/><path d="M160 110h3v7h-3z"/><path d="M163 107h4v3h-4zm-3 83h3v7h-3z"/><path d="M163 187h4v3h-4zm20 0h7v3h-7z"/><path d="M180 190h3v3h-3zm10-7h3v4h-3z"/><path d="M193 187h4v6h-4zm-20 53h4v7h-4z"/><path d="M177 247h3v6h-3z"/><path d="M180 253h3v7h-3z"/><path d="M183 260h7v3h-7z"/><path d="M190 263h3v4h-3zm0-20h3v4h-3z"/><path d="M187 240h3v3h-3z"/><path d="M190 237h3v3h-3zm13 23h4v3h-4z"/><path d="M207 263h3v7h-3z"/><path d="M210 270h3v3h-3zm-10 7h3v6h-3z"/><path d="M203 283h4v7h-4z"/><path d="M207 290h6v3h-6z"/></g><g class="o"><path d="M133 157h4v50h-4zm0 63h4v10h-4zm27-163h3v10h-3z"/><path d="M163 53h4v4h-4z"/><path d="M167 50h10v3h-10z"/><path d="M177 53h3v17h-3z"/><path d="M173 70h4v27h-4zm-6 0h3v27h-3z"/><path d="M163 67h4v3h-4zm0 30h4v3h-4z"/><path d="M160 100h3v3h-3z"/><path d="M157 103h3v4h-3z"/><path d="M153 107h4v3h-4z"/><path d="M150 110h3v3h-3z"/><path d="M147 113h3v7h-3z"/><path d="M143 120h4v7h-4z"/><path d="M140 127h3v10h-3z"/><path d="M137 137h3v20h-3zm56-10h4v10h-4z"/><path d="M190 117h3v10h-3z"/><path d="M187 110h3v7h-3z"/><path d="M183 103h4v7h-4z"/><path d="M180 100h3v3h-3z"/><path d="M177 97h3v3h-3zm-40 106h3v17h-3zm0 27h3v10h-3zm10 30h3v7h-3z"/><path d="M150 257v-4h-3v-6h-4v-7h-3v10h3v10h4v-3h3z"/><path d="M150 257h3v3h-3z"/><path d="M163 273v-3h-6v-10h-4v7h-3v3h3v3h4v7h3v-7h3z"/><path d="M163 267h4v3h-4z"/><path d="M170 257h-3-4v3h4v7h3v-10z"/><path d="M157 253h6v4h-6z"/><path d="M153 247h4v6h-4z"/><path d="M150 240h3v7h-3z"/><path d="M147 230h3v10h-3zm13 50h3v7h-3z"/><path d="M143 223h4v7h-4z"/><path d="M147 207h3v16h-3z"/><path d="M150 197h3v10h-3zm-10 0h3v6h-3zm50 113h7v3h-7zm23 10h17v3h-17z"/><path d="M230 323h13v4h-13z"/><path d="M243 320h10v3h-10z"/><path d="M253 317h4v3h-4z"/><path d="M257 307h3v10h-3z"/><path d="M253 303h4v4h-4z"/><path d="M250 300h3v3h-3z"/><path d="M247 297h3v3h-3z"/><path d="M243 293h4v4h-4z"/><path d="M240 290h3v3h-3z"/><path d="M237 287h3v3h-3z"/><path d="M233 283h4v4h-4z"/><path d="M230 280h3v3h-3z"/><path d="M227 277h3v3h-3z"/><path d="M223 273h4v4h-4z"/><path d="M220 267h3v6h-3z"/><path d="M217 260h3v7h-3z"/><path d="M213 253h4v7h-4z"/><path d="M210 247h3v6h-3z"/><path d="M207 237h3v10h-3z"/><path d="M203 227h4v10h-4zm-40 60h4v6h-4zm24 20h3v3h-3z"/><path d="M167 293h3v5h-3zm16 14h4v3h-4z"/><path d="M170 298h4v3h-4zm10 6h3v3h-3z"/><path d="M174 301h6v3h-6zm23 12h6v4h-6z"/><path d="M203 317h10v3h-10zm-2-107v-73h-4v73h3v17h3v-17h-2z"/></g><g class="o"><path d="M187 307v-4h3v-6h-3v-4h-4v-3h-3v-3h-7v-4h-6v4h-4v3h4v27h-4v13h-3v10h-4v7h4v3h3 10 14v-3h-4v-4h-3v-3h-3v-3h-4v-7h4v-10h3v-7h3v-3h7v-3h-3zm16 10v-4h-6v17h-4v10h-3v7h3v3h4 6 4 3 14v-3h-4v-4h-7v-3h-3v-3h-3v-10h3v-7h3v-3h-10z"/></g>';
        string memory _DEFAULT_NECKLACE =
            '<g class="o"><path d="M190 173h-37v-3h-10v-4h-6v4h3v3h-3v4h6v3h10v4h37v-4h3v-3h-3v-4zm-40 4h-3v-4h3v4zm7 3v-3h3v3h-3zm6 0v-3h4v3h-4zm7 0v-3h3v3h-3zm7 0v-3h3v3h-3zm10 0h-4v-3h4v3z"/><path d="M190 170h3v3h-3z"/><path d="M193 166h4v4h-4zm0 7h4v4h-4z"/></g><g class="w"><path d="M137 170h3v3h-3zm10 3h3v4h-3zm10 4h3v3h-3zm6 0h4v3h-4zm7 0h3v3h-3zm7 0h3v3h-3zm6 0h4v3h-4zm7-4h3v4h-3z"/><path d="M193 170h4v3h-4z"/></g>';
        string memory _DEFAULT_MOUTH =
            '<g class="o"><path d="M183 160v-4h-20v4h-3v3h3v4h24v-7h-4zm-13 3v-3h10v3h-10z" fill="#ad71c8"/><path d="M170 160h10v3h-10z"/></g>';
        string memory _DEFAULT_STANDARD_EYES =
            '<g class="o"><path d="M177 140v3h6v11h10v-11h4v-3h-20z"/><path d="M153 140v3h7v8 3h7 3v-11h3v-3h-20z"/></g><g class="w"><path d="M153 143h7v4h-7z"/><path d="M157 147h3v3h-3zm20-4h6v4h-6z"/><path d="M180 147h3v3h-3z"/></g>';
        string memory _DEFAULT_ALIEN_EYES =
            '<g class="o"><path d="M190 127h3v3h-3zm3 13h4v3h-4zm-42 0h6v6h-6z"/><path d="M151 133h3v7h-3zm10 0h6v4h-6z"/><path d="M157 137h17v6h-17zm3 13h14v3h-14zm17-13h7v16h-7z"/><path d="M184 137h6v6h-6zm0 10h10v6h-10z"/><path d="M187 143h10v4h-10z"/><path d="M190 140h3v3h-3zm-6-10h3v7h-3z"/><path d="M187 130h6v3h-6zm-36 0h10v3h-10zm16 13h7v7h-7zm-10 0h7v7h-7z"/><path d="M164 147h3v3h-3zm29-20h4v6h-4z"/><path d="M194 133h3v7h-3z"/></g><g class="w"><path d="M154 133h7v4h-7z"/><path d="M154 137h3v3h-3zm10 6h3v4h-3zm20 0h3v4h-3zm3-10h7v4h-7z"/><path d="M190 137h4v3h-4z"/></g>';

        {
            // Perform the check for the resolver..
            (address _resolver, bool _resolverIsDeployed) = _isDeployed(
                RESOLVER_SALT,
                type(Banny721TokenUriResolver).creationCode,
                abi.encode(
                    _BANNY_BODY,
                    _DEFAULT_NECKLACE,
                    _DEFAULT_MOUTH,
                    _DEFAULT_STANDARD_EYES,
                    _DEFAULT_ALIEN_EYES,
                    OPERATOR,
                    TRUSTED_FORWARDER
                )
            );

            // Deploy it if it has not been deployed yet.
            resolver = !_resolverIsDeployed
                ? new Banny721TokenUriResolver{salt: RESOLVER_SALT}(
                    _BANNY_BODY,
                    _DEFAULT_NECKLACE,
                    _DEFAULT_MOUTH,
                    _DEFAULT_STANDARD_EYES,
                    _DEFAULT_ALIEN_EYES,
                    OPERATOR,
                    TRUSTED_FORWARDER
                )
                : Banny721TokenUriResolver(_resolver);
        }

        // Desk
        names[0] = "Work Station";
        svgHashes[0] = bytes32(0xab22e30cb6daaac109ea557a14af9b65f680d46cc563a0b25dd42483f9286bf7);
        // Hay field
        names[1] = "Hay Field";
        svgHashes[1] = bytes32(0x62f97f668e227ab9d6eaf5bd35504974f3df175ee2d952c39add59b7d141c0de);
        // Pew pew
        names[2] = "Pew Pew";
        svgHashes[2] = bytes32(0x71f6918188cd0bc9eb1d5baed9340491efb41af1d358bbeb10912a02e95323f8);
        // Bandolph staff
        names[3] = "Bandolph Staff";
        svgHashes[3] = bytes32(0x790e607150e343fd457bb0cefe5fd12cd216b722dabfa19adbee1f1e537fd1c7);
        // Block chain
        names[4] = "Block Chain";
        svgHashes[4] = bytes32(0x5e609d387ea091bc8884a753ddd28dd43b8ed1243b29de6e9354ef1ab109a0b9);
        // Astronaut Head
        names[5] = "Astronaut Head";
        svgHashes[5] = bytes32(0x7054504d4eef582f2e3411df719fba9d90e94c2054bf48e2efa175b4f37cc1e9);
        // Nerd
        names[6] = "Nerd Glasses";
        svgHashes[6] = bytes32(0x964356f8cbc40b81653a219d94da9d49d0bd5b745aa6bf4db16a14aa81c129ac);
        // Banny vision pro
        names[7] = "Banny Vision Pro";
        svgHashes[7] = bytes32(0x12702d5d843aff058610a01286446401be4175c27abaaec144d8970f99db34e2);
        // Cyberpunk glasses
        names[8] = "Cyberpunk Glasses";
        svgHashes[8] = bytes32(0x5930f0bb8cb34d82b88a13391bcccf936e09be535f2848ba7911b2a98615585d);
        // Investor shades
        names[9] = "Investor Shades";
        svgHashes[9] = bytes32(0x4410654936785cff70498421a8805ad2f9d5101a8c18168264ef94df671db10e);
        // Proff glasses
        names[10] = "Proff Glasses";
        svgHashes[10] = bytes32(0x54004065d83ca03befdf72236331f5b532c00920613d8774ebd8edbf277c345a);
        // Gap tooth
        names[11] = "Gap Teeth";
        svgHashes[11] = bytes32(0x5b5a29873435b40784f64c5d9bb5d95ecebd433c57493e38f3eb816a0dd9fd7f);
        // Dorthy shoes
        names[12] = "Dorthy Shoes";
        svgHashes[12] = bytes32(0x67a973e1023d2a9a37270e4345f9e93b30828ec64bc81c0d1d56028f8e976491);
        // Astronaut boots
        names[13] = "Astronaut Boots";
        svgHashes[13] = bytes32(0x539f9417dd22ba8aacd4029753f6058b5f905eef2a3b07acb519c964fc57ce50);
        // Flops
        names[14] = "Flops";
        svgHashes[14] = bytes32(0x0a322735b4b89b7a593a86615ccc03e14867ce1cfd57c1aa9a61a841d9498103);
        // Astronaut Body
        names[15] = "Astronaut Suit";
        svgHashes[15] = bytes32(0xdbcfc1891ab9d56cb964f3432f867a77293352e38edca3b59b34061e46a31b83);
        // Sweatsuit
        names[16] = "Sweatsuit";
        svgHashes[16] = bytes32(0xfbb3a6dde059e3e3115c3e83fd675d1739ec29afa62999fa759ed878f48e9aa2);
        // Dorthy dress
        names[17] = "Dorthy Dress";
        svgHashes[17] = bytes32(0xfc0eda6d0165d339239bfda3cf68d630949b03c588e3b6d45175c6fc8f00e289);
        // Geisha body
        names[18] = "Geisha Gown";
        svgHashes[18] = bytes32(0x5f8c77bc896a90a35580078ee7ea51460b5694aec68db3d749fd1dc0e9b05c6c);
        // Baggies
        names[19] = "Baggies";
        svgHashes[19] = bytes32(0x2f0cab70c7d07048ccc7b6855bba39cdd95be15a109c8eaa401d9be6d503ca2a);
        // Jonny utah shirt
        names[20] = "Jonny Utah Shirt";
        svgHashes[20] = bytes32(0xf62770cf77965461df8528baec000228c713e749b4dcc12e278b1025507dc0ff);
        // Doc coat
        names[21] = "Doc Coat";
        svgHashes[21] = bytes32(0x6650b989b4ad53d12fd306bf4a12f5afbca2072c3241fdcb96e434443039d1f7);
        // Goat jersey
        names[22] = "Goat Jersey";
        svgHashes[22] = bytes32(0xcca8b9f46f75822d78e7f3125ba4832e24ffe1711f6f01d00cdccb6669f752f2);
        // Irie tshirt
        names[23] = "Irie Shirt";
        svgHashes[23] = bytes32(0xd26b2eaad19396b85f4ae09c702717969b72b8c63021821e0d35addd85e7bbd1);
        // Punk jacket
        names[24] = "Punk Jacket";
        svgHashes[24] = bytes32(0x44cb972aab236c8c01afef7addb0f19a0fab02cfdc7b5065d662b53ab970f310);
        // Zipper jacket
        names[25] = "Zipper Jacket";
        svgHashes[25] = bytes32(0x7177dfec617d77cf78e8393fe373b68c7bc755edd1541c0decc952e99ec80304);
        // Zucco tshirt
        names[26] = "Zucco Tshirt";
        svgHashes[26] = bytes32(0x2a69ce643e565cb4fe648dc9b03020b0749ec780748d43153ee4c6770c76adbf);
        // Ice Cube
        names[27] = "Ice Cube";
        svgHashes[27] = bytes32(0x032b50792f9929066168187acd5eeb101f8528f538ef850913c81dc4b6452842);
        // Club beanie
        names[28] = "Club Beanie";
        svgHashes[28] = bytes32(0x0a8d7c8ff075db0e66638bb51eea732a53641b09b39de68d1cbeafe9099f9b6e);
        // Dorthy hair
        names[29] = "Dorthy Hair";
        svgHashes[29] = bytes32(0x5f2bec3082d7039474f6cba827a3fbd4d4f8e21f22d304edfbc6de77a8b529cf);
        // Farmer hat
        names[30] = "Farmer Hat";
        svgHashes[30] = bytes32(0xcf90bc8459345bcfae00796c4641c0bc8868c01d6339a54ef4d3c4fa1737cfd8);
        // Geisha hair
        names[31] = "Geisha Hair";
        svgHashes[31] = bytes32(0x17b939b04709c357480bdfa54cf2007d7898f4bf048bf12efa6cd8e3af4d711c);
        // Headphones
        names[32] = "Headphones";
        svgHashes[32] = bytes32(0xf1850876ede53102140881e04a4a0e532ba6a08bc0fb64dee279d11c98d64dbf);
        // Natty dread
        names[33] = "Natty Dred";
        svgHashes[33] = bytes32(0x04ae3342ce08da16f61d32e4ce7034dff0223e462afa48019b90c94afc19b939);
        // Peach hair
        names[34] = "Peach Hair";
        svgHashes[34] = bytes32(0xdf7b9e74c552908290a05388f905a503978a289c44ffb61e510df43f2955d435);
        // Proff hair
        names[35] = "Proff Hair";
        svgHashes[35] = bytes32(0x501769b2b47a8aedf4b328f6cf0076200df07ce2087f5e082f49e815f54595b9);
        // Catana
        names[36] = "Catana";
        svgHashes[36] = bytes32(0xbe7e7bb20da87fffa92e867bf0cd3267df180e24ba6eae7a1d434c56856ef2f5);
        // Chefs knife
        names[37] = "Chefs Knife";
        svgHashes[37] = bytes32(0x705180b5aee8e57d0a0783d22fc30dc95e3e84fac36e9d96fef96fabfa58d1f9);
        // Cheap beer
        names[38] = "Cheap Beer";
        svgHashes[38] = bytes32(0x993a2c657f43e19820f3e23677e650705d0c8c6a0ccd88a381aa54d2da7ba047);
        // Constitution
        names[39] = "Constitution";
        svgHashes[39] = bytes32(0xaf0826d8eac1e57789077f43e6f979488da6f619f72f9f0ff50a52ebcca3bfa3);
        // DJ Deck
        names[40] = "DJ Deck";
        svgHashes[40] = bytes32(0x2c9538556986d134ddec2831e768233f587b242e887df9bb359b3aefffa3c5a6);
        // Gas can
        names[41] = "Gas Can";
        svgHashes[41] = bytes32(0x89808b70d019077e4f986b4a60af4ec15fc72ed022bc5e5476441d98f8ce1d1d);
        // Lightsaber
        names[42] = "Lightsaber";
        svgHashes[42] = bytes32(0xf7017a80e9fa4c3fc052a701c04374176620a8e5befa39b708a51293c4d8f406);
        // Potion
        names[43] = "Potion";
        svgHashes[43] = bytes32(0xefdbac65db3868ead1c1093ea20f0b2d77e9095567f6358e246ba160ec545e09);
        // Dagger
        names[44] = "Dagger";
        svgHashes[44] = bytes32(0xaf60de81f2609b847b7d6e97ef6c09c9e3d91cabe6f955bd8828f342f1558738);
        // Duct Tape
        names[45] = "Duct Tape";
        svgHashes[45] = bytes32(0x962ce657908ee4fb58b3e2d1f77109b36428e7a4446d6127bcb6c06aa2360637);
        // Wheat straw
        names[46] = "Wheat Straw";
        svgHashes[46] = bytes32(0x112b8217bb82aebc91e80c935244dce8aa30d4d8df5f98382054b97037dc0c94);

        uint256[] memory productIds = new uint256[](47);
        for (uint256 i; i < 47; i++) {
            productIds[i] = i + 5;
        }

        hook.setMetadata({
            baseUri: "",
            contractUri: "",
            tokenUriResolver: resolver,
            encodedIPFSUriTierId: 0,
            encodedIPFSUri: bytes32(0)
        });
        resolver.setSvgHashsOf(productIds, svgHashes);
        resolver.setProductNames(productIds, names);
        resolver.setSvgBaseUri("https://bannyverse.infura-ipfs.io/ipfs/");
    }

    function _isDeployed(
        bytes32 salt,
        bytes memory creationCode,
        bytes memory arguments
    )
        internal
        view
        returns (address, bool)
    {
        address _deployedTo = vm.computeCreate2Address({
            salt: salt,
            initCodeHash: keccak256(abi.encodePacked(creationCode, arguments)),
            // Arachnid/deterministic-deployment-proxy address.
            deployer: address(0x4e59b44847b379578588920cA78FbF26c0B4956C)
        });

        // Return if code is already present at this address.
        return (_deployedTo, address(_deployedTo).code.length != 0);
    }
}
