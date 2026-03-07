// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@bananapus/721-hook-v6/src/abstract/ERC721.sol";
import {IJB721TiersHook} from "@bananapus/721-hook-v6/src/interfaces/IJB721TiersHook.sol";
import {IJB721TiersHookStore} from "@bananapus/721-hook-v6/src/interfaces/IJB721TiersHookStore.sol";
import {IJB721TokenUriResolver} from "@bananapus/721-hook-v6/src/interfaces/IJB721TokenUriResolver.sol";
import {JB721Tier} from "@bananapus/721-hook-v6/src/structs/JB721Tier.sol";
import {JBIpfsDecoder} from "@bananapus/721-hook-v6/src/libraries/JBIpfsDecoder.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "lib/base64/base64.sol";

import {IBanny721TokenUriResolver} from "./interfaces/IBanny721TokenUriResolver.sol";

/// @notice Banny asset manager. Stores and shows banny bodies in backgrounds with outfits on.
contract Banny721TokenUriResolver is
    Ownable,
    ERC2771Context,
    ReentrancyGuard,
    IJB721TokenUriResolver,
    IBanny721TokenUriResolver,
    IERC721Receiver
{
    using Strings for uint256;

    error Banny721TokenUriResolver_CantAccelerateTheLock();
    error Banny721TokenUriResolver_ContentsAlreadyStored();
    error Banny721TokenUriResolver_ContentsMismatch();
    error Banny721TokenUriResolver_HashAlreadyStored();
    error Banny721TokenUriResolver_HashNotFound();
    error Banny721TokenUriResolver_HeadAlreadyAdded();
    error Banny721TokenUriResolver_OutfitChangesLocked();
    error Banny721TokenUriResolver_SuitAlreadyAdded();
    error Banny721TokenUriResolver_UnauthorizedBannyBody();
    error Banny721TokenUriResolver_UnauthorizedOutfit();
    error Banny721TokenUriResolver_UnauthorizedBackground();
    error Banny721TokenUriResolver_UnorderedCategories();
    error Banny721TokenUriResolver_UnrecognizedCategory();
    error Banny721TokenUriResolver_UnrecognizedBackground();
    error Banny721TokenUriResolver_UnrecognizedProduct();
    error Banny721TokenUriResolver_UnauthorizedTransfer();

    //*********************************************************************//
    // ------------------------ private constants ------------------------ //
    //*********************************************************************//

    /// @notice Just a kind reminder to our readers.
    /// @dev Used in 721 token ID generation.
    uint256 private constant _ONE_BILLION = 1_000_000_000;

    /// @notice The duration that banny bodies can be locked for.
    uint256 private constant _LOCK_DURATION = 7 days;

    uint8 private constant _BODY_CATEGORY = 0;
    uint8 private constant _BACKGROUND_CATEGORY = 1;
    uint8 private constant _BACKSIDE_CATEGORY = 2;
    uint8 private constant _NECKLACE_CATEGORY = 3;
    uint8 private constant _HEAD_CATEGORY = 4;
    uint8 private constant _EYES_CATEGORY = 5;
    uint8 private constant _GLASSES_CATEGORY = 6;
    uint8 private constant _MOUTH_CATEGORY = 7;
    uint8 private constant _LEGS_CATEGORY = 8;
    uint8 private constant _SUIT_CATEGORY = 9;
    uint8 private constant _SUIT_BOTTOM_CATEGORY = 10;
    uint8 private constant _SUIT_TOP_CATEGORY = 11;
    uint8 private constant _HEADTOP_CATEGORY = 12;
    uint8 private constant _HAND_CATEGORY = 13;
    uint8 private constant _SPECIAL_SUIT_CATEGORY = 14;
    uint8 private constant _SPECIAL_LEGS_CATEGORY = 15;
    uint8 private constant _SPECIAL_HEAD_CATEGORY = 16;
    uint8 private constant _SPECIAL_BODY_CATEGORY = 17;

    uint8 private constant ALIEN_UPC = 1;
    uint8 private constant PINK_UPC = 2;
    uint8 private constant ORANGE_UPC = 3;
    uint8 private constant ORIGINAL_UPC = 4;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The amount of time each banny body is currently locked for.
    /// @custom:param hook The hook address of the collection.
    /// @custom:param bannyBodyId The ID of the banny body to lock.
    mapping(address hook => mapping(uint256 upc => uint256)) public override outfitLockedUntil;

    /// @notice The base of the domain hosting the SVG files that can be lazily uploaded to the contract.
    string public override svgBaseUri;

    /// @notice The description used in token metadata.
    string public override svgDescription;

    /// @notice The external URL used in token metadata.
    string public override svgExternalUrl;

    /// @notice The banny body and outfit SVG hash files.
    /// @custom:param upc The universal product code that the SVG hash represent.
    mapping(uint256 upc => bytes32) public override svgHashOf;

    string public override DEFAULT_ALIEN_EYES;
    string public override DEFAULT_MOUTH;
    string public override DEFAULT_NECKLACE;
    string public override DEFAULT_STANDARD_EYES;
    string public override BANNY_BODY;

    //*********************************************************************//
    // --------------------- internal stored properties ------------------ //
    //*********************************************************************//

    /// @notice The outfits currently attached to each banny body.
    /// @dev Naked Banny's will only be shown with outfits currently owned by the owner of the banny body.
    /// @custom:param hook The hook address of the collection.
    /// @custom:param bannyBodyId The ID of the banny body of the outfits.
    mapping(address hook => mapping(uint256 bannyBodyId => uint256[])) internal _attachedOutfitIdsOf;

    /// @notice The background currently attached to each banny body.
    /// @dev Naked Banny's will only be shown with a background currently owned by the owner of the banny body.
    /// @custom:param hook The hook address of the collection.
    /// @custom:param bannyBodyId The ID of the banny body of the background.
    mapping(address hook => mapping(uint256 bannyBodyId => uint256)) internal _attachedBackgroundIdOf;

    /// @notice The name of each product.
    /// @custom:param upc The universal product code that the name belongs to.
    mapping(uint256 upc => string) internal _customProductNameOf;

    /// @notice The banny body and outfit SVG files.
    /// @custom:param upc The universal product code that the SVG contents represent.
    mapping(uint256 upc => string) internal _svgContentOf;

    /// @notice The ID of the banny body each background is being used by.
    /// @custom:param hook The hook address of the collection.
    /// @custom:param backgroundId The ID of the background.
    mapping(address hook => mapping(uint256 backgroundId => uint256)) internal _userOf;

    /// @notice The ID of the banny body each outfit is being worn by.
    /// @custom:param hook The hook address of the collection.
    /// @custom:param outfitId The ID of the outfit.
    mapping(address hook => mapping(uint256 outfitId => uint256)) internal _wearerOf;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param bannyBody The SVG of the banny body.
    /// @param defaultNecklace The SVG of the default necklace.
    /// @param defaultMouth The SVG of the default mouth.
    /// @param defaultStandardEyes The SVG of the default standard eyes.
    /// @param defaultAlienEyes The SVG of the default alien eyes.
    /// @param owner The owner allowed to add SVG files that correspond to product IDs.
    /// @param trustedForwarder The trusted forwarder for the ERC2771Context.
    constructor(
        string memory bannyBody,
        string memory defaultNecklace,
        string memory defaultMouth,
        string memory defaultStandardEyes,
        string memory defaultAlienEyes,
        address owner,
        address trustedForwarder
    )
        Ownable(owner)
        ERC2771Context(trustedForwarder)
    {
        BANNY_BODY = bannyBody;
        DEFAULT_NECKLACE = defaultNecklace;
        DEFAULT_MOUTH = defaultMouth;
        DEFAULT_STANDARD_EYES = defaultStandardEyes;
        DEFAULT_ALIEN_EYES = defaultAlienEyes;
    }

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Returns the SVG showing a dressed banny body in a background.
    /// @param tokenId The ID of the token to show. If the ID belongs to a banny body, it will be shown with its
    /// current outfits in its current background.
    /// @return tokenUri The URI representing the SVG.
    function tokenUriOf(address hook, uint256 tokenId) external view override returns (string memory) {
        // Get a reference to the product for the given token ID.
        JB721Tier memory product = _productOfTokenId({hook: hook, tokenId: tokenId});

        // If the token's product ID doesn't exist, return an empty uri.
        if (product.id == 0) return "";

        string memory contents;
        string memory extraMetadata = "";
        string memory attributes = '"attributes": [';

        // If this isn't a banny body, return the asset SVG alone (or on a manakin banny).
        if (product.category != _BODY_CATEGORY) {
            // Keep a reference to the SVG contents.
            contents = _svgOf({hook: hook, upc: product.id});

            // Layer the outfit SVG over the mannequin Banny
            // Start with the mannequin SVG if we're not returning a background.
            if (bytes(contents).length != 0) {
                if (product.category != _BACKGROUND_CATEGORY) {
                    contents = string.concat(_mannequinBannySvg(), contents);
                }
                contents = _layeredSvg(contents);
            }

            // If the background or outfit is attached to a banny body, add it to extraMetadata.
            if (product.category == _BACKGROUND_CATEGORY) {
                uint256 bannyBodyId = userOf({hook: hook, backgroundId: tokenId});
                extraMetadata = string.concat('"usedByBannyBodyId": ', bannyBodyId.toString(), ",");
                attributes = string.concat(
                    attributes, '{"trait_type": "Used by Banny", "value": ', bannyBodyId.toString(), "},"
                );
            } else {
                uint256 bannyBodyId = wearerOf({hook: hook, outfitId: tokenId});
                extraMetadata = string.concat('"wornByBannyBodyId": ', bannyBodyId.toString(), ",");
                attributes = string.concat(
                    attributes, '{"trait_type": "Worn by Banny", "value": ', bannyBodyId.toString(), "},"
                );
            }
        } else {
            // Compose the contents.
            contents = svgOf({
                hook: hook, tokenId: tokenId, shouldDressBannyBody: true, shouldIncludeBackgroundOnBannyBody: true
            });

            // Get a reference to each asset ID currently attached to the banny body.
            (uint256 backgroundId, uint256[] memory outfitIds) = assetIdsOf({hook: hook, bannyBodyId: tokenId});

            extraMetadata = '"outfitIds": [';

            for (uint256 i; i < outfitIds.length; i++) {
                extraMetadata = string.concat(extraMetadata, outfitIds[i].toString());

                // Add a comma if it's not the last outfit.
                if (i < outfitIds.length - 1) {
                    extraMetadata = string.concat(extraMetadata, ",");
                }
            }

            extraMetadata = string.concat(extraMetadata, "],");

            for (uint256 i; i < outfitIds.length; i++) {
                JB721Tier memory outfitProduct = _productOfTokenId({hook: hook, tokenId: outfitIds[i]});

                attributes = string.concat(
                    attributes,
                    '{"trait_type": "',
                    _categoryNameOf(outfitProduct.category),
                    '", "value": "',
                    _productNameOf(outfitProduct.id),
                    '"},'
                );
            }

            if (backgroundId != 0) {
                extraMetadata = string.concat(extraMetadata, '"backgroundId": ', backgroundId.toString(), ",");
                attributes = string.concat(
                    attributes,
                    '{"trait_type": "Background", "value": "',
                    _productNameOf(_productOfTokenId({hook: hook, tokenId: backgroundId}).id),
                    '"},'
                );
            } else {
                attributes = string.concat(attributes, '{"trait_type": "Background", "value": ""},');
            }

            // If the token has an owner, check if the owner has locked the token.
            uint256 lockedUntil = outfitLockedUntil[hook][tokenId];
            if (lockedUntil > block.timestamp) {
                extraMetadata = string.concat(extraMetadata, '"changesLockedUntil": ', lockedUntil.toString(), ",");
                attributes = string.concat(
                    attributes, '{"trait_type": "Changes locked until", "value": ', lockedUntil.toString(), "},"
                );
            }
        }

        if (bytes(contents).length == 0) {
            // If the product's category is greater than the last expected category, use the default base URI of the 721
            // contract. Otherwise use the SVG URI.
            string memory baseUri =
                product.category > _SPECIAL_BODY_CATEGORY ? IJB721TiersHook(hook).baseURI() : svgBaseUri;

            // Fallback to returning an IPFS hash if present.
            return JBIpfsDecoder.decode({
                baseUri: baseUri, hexString: _storeOf(hook).encodedTierIPFSUriOf({hook: hook, tokenId: tokenId})
            });
        }

        // Get a reference to the pricing context.
        // slither-disable-next-line unused-return
        (uint256 currency, uint256 decimals,) = IJB721TiersHook(hook).pricingContext();

        attributes = string.concat(
            attributes,
            '{"trait_type": "Product name", "value": "',
            _productNameOf(product.id),
            '"}, {"trait_type": "Category name", "value": "',
            _categoryNameOf(product.category),
            '"}, {"trait_type": "Total supply", "value": "',
            uint256(product.initialSupply).toString(),
            '"}]'
        );

        // Build the pricing metadata separately to avoid stack too deep.
        string memory pricingMetadata = string.concat(
            ', "supply": ',
            uint256(product.initialSupply).toString(),
            ', "remaining": ',
            uint256(product.remainingSupply).toString(),
            ', "price": ',
            uint256(product.price).toString(),
            ', "decimals": ',
            decimals.toString(),
            ', "currency": ',
            currency.toString(),
            ', "discount": ',
            uint256(product.discountPercent).toString()
        );

        return _encodeTokenUri({
            tokenId: tokenId,
            product: product,
            extraMetadata: string.concat(pricingMetadata, ", ", extraMetadata, attributes),
            imageContents: Base64.encode(abi.encodePacked(contents))
        });
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice The assets currently attached to each banny body.
    /// @custom:param hook The hook address of the collection.
    /// @param bannyBodyId The ID of the banny body shown with the associated assets.
    /// @return backgroundId The background attached to the banny body.
    /// @return outfitIds The outfits attached to the banny body.
    function assetIdsOf(
        address hook,
        uint256 bannyBodyId
    )
        public
        view
        override
        returns (uint256 backgroundId, uint256[] memory outfitIds)
    {
        // Keep a reference to the outfit IDs currently stored as attached to the banny body.
        uint256[] memory storedOutfitIds = _attachedOutfitIdsOf[hook][bannyBodyId];

        // Initiate the outfit IDs array with the same number of entries.
        outfitIds = new uint256[](storedOutfitIds.length);

        // Keep a reference to the number of included outfits.
        uint256 numberOfIncludedOutfits = 0;

        // Keep a reference to the stored outfit ID being iterated on.
        uint256 storedOutfitId;

        // Return the outfit's that are still being worn by the banny body.
        for (uint256 i; i < storedOutfitIds.length; i++) {
            // Set the stored outfit ID being iterated on.
            storedOutfitId = storedOutfitIds[i];

            // If the stored outfit is still being worn, return it.
            if (wearerOf({hook: hook, outfitId: storedOutfitId}) == bannyBodyId) {
                outfitIds[numberOfIncludedOutfits++] = storedOutfitId;
            }
        }

        // Resize the array to the actual number of included outfits (remove trailing zeros).
        assembly {
            mstore(outfitIds, numberOfIncludedOutfits)
        }

        // Keep a reference to the background currently stored as attached to the banny body.
        uint256 storedBackgroundOf = _attachedBackgroundIdOf[hook][bannyBodyId];

        // If the background is still being used, return it.
        if (userOf({hook: hook, backgroundId: storedBackgroundOf}) == bannyBodyId) backgroundId = storedBackgroundOf;
    }

    /// @notice Returns the name of the token.
    /// @param hook The hook storing the assets.
    /// @param tokenId The ID of the token to show.
    /// @return fullName The full name of the token.
    /// @return categoryName The name of the token's category.
    /// @return productName The name of the token's product.
    function namesOf(
        address hook,
        uint256 tokenId
    )
        public
        view
        override
        returns (string memory, string memory, string memory)
    {
        // Get a reference to the product for the given token ID.
        JB721Tier memory product = _productOfTokenId({hook: hook, tokenId: tokenId});

        return (
            _fullNameOf({tokenId: tokenId, product: product}),
            _categoryNameOf(product.category),
            _productNameOf(product.id)
        );
    }

    /// @notice Returns the SVG showing either a banny body with/without outfits and a background, or the stand alone
    /// outfit
    /// or background.
    /// @param hook The hook storing the assets.
    /// @param tokenId The ID of the token to show. If the ID belongs to a banny body, it will be shown with its
    /// current outfits in its current background if specified.
    /// @param shouldDressBannyBody Whether the banny body should be dressed.
    /// @param shouldIncludeBackgroundOnBannyBody Whether the background should be included on the banny body.
    /// @return svg The SVG.
    function svgOf(
        address hook,
        uint256 tokenId,
        bool shouldDressBannyBody,
        bool shouldIncludeBackgroundOnBannyBody
    )
        public
        view
        override
        returns (string memory)
    {
        // Get a reference to the product for the given token ID.
        JB721Tier memory product = _productOfTokenId({hook: hook, tokenId: tokenId});

        // If the token's product doesn't exist, return an empty uri.
        if (product.id == 0) return "";

        // Compose the contents.
        string memory contents;

        // If this isn't a banny body and there's an SVG available, return the asset SVG alone.
        if (product.category != _BODY_CATEGORY) {
            // Keep a reference to the SVG contents.
            contents = _svgOf({hook: hook, upc: product.id});

            // Return the svg if it exists.
            return (bytes(contents).length == 0) ? "" : _layeredSvg(contents);
        }

        // Get a reference to each asset ID currently attached to the banny body.
        (uint256 backgroundId, uint256[] memory outfitIds) = assetIdsOf({hook: hook, bannyBodyId: tokenId});

        // Add the background if needed.
        if (backgroundId != 0 && shouldIncludeBackgroundOnBannyBody) {
            contents = string.concat(
                contents, _svgOf({hook: hook, upc: _productOfTokenId({hook: hook, tokenId: backgroundId}).id})
            );
        }

        // Start with the banny body.
        contents = string.concat(contents, _bannyBodySvgOf({upc: product.id}));

        if (shouldDressBannyBody) {
            // Get the outfit contents.
            string memory outfitContents = _outfitContentsFor({hook: hook, outfitIds: outfitIds, bodyUpc: product.id});

            // Add the outfit contents if there are any.
            if (bytes(outfitContents).length != 0) {
                contents = string.concat(contents, outfitContents);
            }
        }

        // Return the SVG contents.
        return _layeredSvg(contents);
    }

    /// @notice Checks to see which banny body is currently using a particular background.
    /// @param hook The hook address of the collection.
    /// @param backgroundId The ID of the background being used.
    /// @return The ID of the banny body using the background.
    function userOf(address hook, uint256 backgroundId) public view override returns (uint256) {
        // Get a reference to the banny body using the background.
        uint256 bannyBodyId = _userOf[hook][backgroundId];

        // If no banny body is wearing the outfit, or if its no longer the background attached, return 0.
        if (bannyBodyId == 0 || _attachedBackgroundIdOf[hook][bannyBodyId] != backgroundId) return 0;

        // Return the banny body ID.
        return bannyBodyId;
    }

    /// @notice Checks to see which banny body is currently wearing a particular outfit.
    /// @param hook The hook address of the collection.
    /// @param outfitId The ID of the outfit being worn.
    /// @return The ID of the banny body wearing the outfit.
    function wearerOf(address hook, uint256 outfitId) public view override returns (uint256) {
        // Get a reference to the banny body wearing the outfit.
        uint256 bannyBodyId = _wearerOf[hook][outfitId];

        // If no banny body is wearing the outfit, return 0.
        if (bannyBodyId == 0) return 0;

        // Keep a reference to the outfit IDs currently attached to a banny body.
        uint256[] memory attachedOutfitIds = _attachedOutfitIdsOf[hook][bannyBodyId];

        for (uint256 i; i < attachedOutfitIds.length; i++) {
            // If the outfit is still attached, return the banny body ID.
            if (attachedOutfitIds[i] == outfitId) return bannyBodyId;
        }

        // If the outfit is no longer attached, return 0.
        return 0;
    }

    //*********************************************************************//
    // -------------------------- internal views ------------------------- //
    //*********************************************************************//

    /// @notice The name of each token's category.
    /// @param category The category of the token being named.
    /// @return name The token's category name.
    function _categoryNameOf(uint256 category) internal pure returns (string memory) {
        if (category == _BODY_CATEGORY) {
            return "Banny body";
        } else if (category == _BACKGROUND_CATEGORY) {
            return "Background";
        } else if (category == _BACKSIDE_CATEGORY) {
            return "Backside";
        } else if (category == _LEGS_CATEGORY) {
            return "Legs";
        } else if (category == _NECKLACE_CATEGORY) {
            return "Necklace";
        } else if (category == _EYES_CATEGORY) {
            return "Eyes";
        } else if (category == _GLASSES_CATEGORY) {
            return "Glasses";
        } else if (category == _MOUTH_CATEGORY) {
            return "Mouth";
        } else if (category == _HEADTOP_CATEGORY) {
            return "Head top";
        } else if (category == _HEAD_CATEGORY) {
            return "Head";
        } else if (category == _SUIT_CATEGORY) {
            return "Suit";
        } else if (category == _SUIT_TOP_CATEGORY) {
            return "Suit top";
        } else if (category == _SUIT_BOTTOM_CATEGORY) {
            return "Suit bottom";
        } else if (category == _HAND_CATEGORY) {
            return "Fist";
        } else if (category == _SPECIAL_SUIT_CATEGORY) {
            return "Special Suit";
        } else if (category == _SPECIAL_LEGS_CATEGORY) {
            return "Special Legs";
        } else if (category == _SPECIAL_HEAD_CATEGORY) {
            return "Special Head";
        } else if (category == _SPECIAL_BODY_CATEGORY) {
            return "Special Body";
        }
        return "";
    }

    /// @dev ERC-2771 specifies the context as being a single address (20 bytes).
    function _contextSuffixLength() internal view virtual override(ERC2771Context, Context) returns (uint256) {
        return super._contextSuffixLength();
    }

    /// @notice Make sure the message sender own's the token.
    /// @param hook The 721 contract of the token having ownership checked.
    /// @param upc The product's UPC to check ownership of.
    function _checkIfSenderIsOwner(address hook, uint256 upc) internal view {
        if (IERC721(hook).ownerOf(upc) != _msgSender()) revert Banny721TokenUriResolver_UnauthorizedBannyBody();
    }

    /// @notice The fills for a product.
    /// @param upc The ID of the token whose product's fills are being returned.
    /// @return fills The fills for the product.
    function _fillsFor(uint256 upc)
        internal
        pure
        returns (
            string memory,
            string memory,
            string memory,
            string memory,
            string memory,
            string memory,
            string memory
        )
    {
        if (upc == ALIEN_UPC) {
            return ("67d757", "30a220", "217a15", "09490f", "e483ef", "dc2fef", "dc2fef");
        } else if (upc == PINK_UPC) {
            return ("ffd8c5", "ff96a9", "fe588b", "c92f45", "ffd8c5", "ff96a9", "fe588b");
        } else if (upc == ORANGE_UPC) {
            return ("f3a603", "ff7c02", "fd3600", "c32e0d", "f3a603", "ff7c02", "fd3600");
        } else if (upc == ORIGINAL_UPC) {
            return ("ffe900", "ffc700", "f3a603", "965a1a", "ffe900", "ffc700", "f3a603");
        }

        revert Banny721TokenUriResolver_UnrecognizedProduct();
    }

    /// @notice Encode the token URI JSON with base64.
    function _encodeTokenUri(
        uint256 tokenId,
        JB721Tier memory product,
        string memory extraMetadata,
        string memory imageContents
    )
        internal
        view
        returns (string memory)
    {
        return string.concat(
            "data:application/json;base64,",
            Base64.encode(
                abi.encodePacked(
                    abi.encodePacked(
                        '{"name":"',
                        _fullNameOf({tokenId: tokenId, product: product}),
                        '", "productName": "',
                        _productNameOf(product.id),
                        '", "categoryName": "',
                        _categoryNameOf(product.category),
                        '", "tokenId": ',
                        tokenId.toString(),
                        ', "upc": ',
                        uint256(product.id).toString(),
                        ', "category": ',
                        uint256(product.category).toString()
                    ),
                    extraMetadata,
                    abi.encodePacked(
                        ', "description":"',
                        svgDescription,
                        '","external_url":"',
                        svgExternalUrl,
                        '","image":"data:image/svg+xml;base64,',
                        imageContents,
                        '"}'
                    )
                )
            )
        );
    }

    /// @notice The full name of each product, including category and inventory.
    /// @param tokenId The ID of the token being named.
    /// @param product The product of the token being named.
    /// @return name The full name.
    function _fullNameOf(uint256 tokenId, JB721Tier memory product) internal view returns (string memory name) {
        // Start with the item's name.
        name = string.concat(_productNameOf(product.id), " ");

        // Get just the token ID without the product ID included.
        uint256 rawTokenId = tokenId % _ONE_BILLION;

        string memory remainingString = " remaining";

        // If there's a raw token id, append it to the name before appending it to the category.
        if (rawTokenId != 0) {
            name = string.concat(name, rawTokenId.toString(), "/", uint256(product.initialSupply).toString());
        } else if (product.remainingSupply == 0) {
            name = string.concat(
                name,
                " (SOLD OUT) ",
                uint256(product.remainingSupply).toString(),
                "/",
                uint256(product.initialSupply).toString(),
                remainingString
            );
        } else {
            name = string.concat(
                name,
                uint256(product.remainingSupply).toString(),
                "/",
                uint256(product.initialSupply).toString(),
                remainingString
            );
        }

        // Append a separator.
        name = string.concat(name, ": ");

        // Get a reference to the category's name.
        string memory categoryName = _categoryNameOf(product.category);

        // If there's a category name, append it.
        if (bytes(categoryName).length != 0) {
            name = string.concat(name, categoryName, " ");
        }

        // Append the product ID as a universal product code.
        name = string.concat(name, "UPC #", uint256(product.id).toString());
    }

    /// @notice Returns the standard dimension SVG containing dynamic contents and SVG metadata.
    /// @param contents The contents of the SVG
    /// @return svg The SVG contents.
    function _layeredSvg(string memory contents) internal pure returns (string memory) {
        return string.concat(
            '<svg width="400" height="400" viewBox="0 0 400 400" fill="white" xmlns="http://www.w3.org/2000/svg"><style>.o{fill:#050505;}.w{fill:#f9f9f9;}</style>',
            contents,
            "</svg>"
        );
    }

    /// @notice The SVG contents for a mannequin banny.
    /// @return contents The SVG contents of the mannequin banny.
    function _mannequinBannySvg() internal view returns (string memory) {
        string memory fillNoneString = string.concat("{fill:none;}");
        return string.concat(
            "<style>.o{fill:#808080;}.b1",
            fillNoneString,
            ".b2",
            fillNoneString,
            ".b3",
            fillNoneString,
            ".b4",
            fillNoneString,
            ".a1",
            fillNoneString,
            ".a2",
            fillNoneString,
            ".a3",
            fillNoneString,
            "</style>",
            BANNY_BODY
        );
    }

    /// @notice Returns the calldata, preferred to use over `msg.data`
    /// @return calldata the `msg.data` of this call
    function _msgData() internal view override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /// @notice Returns the sender, preferred to use over `msg.sender`
    /// @return sender the sender address of this call.
    function _msgSender() internal view override(ERC2771Context, Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /// @notice The SVG contents for a banny body.
    /// @param upc The ID of the token whose product's SVG is being returned.
    /// @return contents The SVG contents of the banny body.
    function _bannyBodySvgOf(uint256 upc) internal view returns (string memory) {
        (
            string memory b1,
            string memory b2,
            string memory b3,
            string memory b4,
            string memory a1,
            string memory a2,
            string memory a3
        ) = _fillsFor(upc);
        return string.concat(
            "<style>.b1{fill:#",
            b1,
            ";}.b2{fill:#",
            b2,
            ";}.b3{fill:#",
            b3,
            ";}.b4{fill:#",
            b4,
            ";}.a1{fill:#",
            a1,
            ";}.a2{fill:#",
            a2,
            ";}.a3{fill:#",
            a3,
            ";}</style>",
            BANNY_BODY
        );
    }

    /// @notice The SVG contents for a list of outfit IDs.
    /// @param hook The 721 contract that the product belongs to.
    /// @param outfitIds The IDs of the outfits that'll be associated with the specified banny.
    /// @param bodyUpc The UPC of the banny body being dressed (used for default eyes selection).
    /// @return contents The SVG contents of the outfits.
    function _outfitContentsFor(
        address hook,
        uint256[] memory outfitIds,
        uint256 bodyUpc
    )
        internal
        view
        returns (string memory contents)
    {
        // Get a reference to the number of outfits are on the banny body.
        uint256 numberOfOutfits = outfitIds.length;

        // Keep a reference to if certain accessories have been added.
        bool hasNecklace;
        bool hasHead;
        bool hasEyes;
        bool hasMouth;

        // Keep a reference to the custom necklace. Needed because the custom necklace is layered differently than the
        // default.
        string memory customNecklace;

        // For each outfit, add the SVG layer if it's owned by the same owner as the banny body being dressed.
        // Loop once more to make sure all default outfits are added.
        for (uint256 i; i < numberOfOutfits + 1; i++) {
            // Keep a reference to the outfit ID being iterated on.
            uint256 outfitId;

            // Keep a reference to the category of the outfit being iterated on.
            uint256 category;

            // Keep a reference to the upc of the outfit being iterated on.
            uint256 upc;

            // If the outfit is within the bounds of the number of outfits there are, add it normally.
            if (i < numberOfOutfits) {
                // Set the outfit ID being iterated on.
                outfitId = outfitIds[i];

                // Get the product of the outfit being iterated on.
                JB721Tier memory product = _productOfTokenId({hook: hook, tokenId: outfitId});

                // Set the category of the outfit being iterated on.
                category = product.category;

                // Set the upc of the outfit being iterated on.
                upc = product.id;
            } else {
                // Set the category to be more than all other categories to force adding defaults.
                category = _SPECIAL_BODY_CATEGORY + 1;
                outfitId = 0;
                upc = 0;
            }

            if (category == _NECKLACE_CATEGORY) {
                hasNecklace = true;
                customNecklace = _svgOf({hook: hook, upc: upc});
            } else if (category > _NECKLACE_CATEGORY && !hasNecklace) {
                contents = string.concat(contents, DEFAULT_NECKLACE);
                hasNecklace = true;
            }

            if (category == _HEAD_CATEGORY) {
                hasHead = true;
            }

            if (category == _EYES_CATEGORY) {
                hasEyes = true;
            } else if (category > _EYES_CATEGORY && !hasEyes && !hasHead) {
                if (bodyUpc == ALIEN_UPC) contents = string.concat(contents, DEFAULT_ALIEN_EYES);
                else contents = string.concat(contents, DEFAULT_STANDARD_EYES);

                hasEyes = true;
            }

            if (category == _MOUTH_CATEGORY) {
                hasMouth = true;
            } else if (category > _MOUTH_CATEGORY && !hasMouth && !hasHead) {
                contents = string.concat(contents, DEFAULT_MOUTH);
                hasMouth = true;
            }

            // Add the custom necklace if needed.
            if (category > _SUIT_TOP_CATEGORY && bytes(customNecklace).length != 0) {
                contents = string.concat(contents, customNecklace);
                // Reset.
                customNecklace = "";
            }

            // Add the outfit if needed.
            if (outfitId != 0 && category != _NECKLACE_CATEGORY) {
                contents = string.concat(contents, _svgOf({hook: hook, upc: upc}));
            }
        }
    }

    /// @notice The name of each token's product type.
    /// @param upc The ID of the token whose product type is being named.
    /// @return name The item's product name.
    function _productNameOf(uint256 upc) internal view returns (string memory) {
        // Get the token's name.
        if (upc == ALIEN_UPC) {
            return "Alien";
        } else if (upc == PINK_UPC) {
            return "Pink";
        } else if (upc == ORANGE_UPC) {
            return "Orange";
        } else if (upc == ORIGINAL_UPC) {
            return "Original";
        } else {
            // Get the product's name that has been uploaded.
            return _customProductNameOf[upc];
        }
    }

    /// @notice Get the product of the 721 with the provided token ID in the provided 721 contract.
    /// @param hook The 721 contract that the product belongs to.
    /// @param tokenId The token ID of the 721 to get the product of.
    /// @return product The product.
    function _productOfTokenId(address hook, uint256 tokenId) internal view returns (JB721Tier memory) {
        return _storeOf(hook).tierOfTokenId({hook: hook, tokenId: tokenId, includeResolvedUri: false});
    }

    /// @notice The store of the hook.
    /// @param hook The hook to get the store of.
    /// @return store The store of the hook.
    function _storeOf(address hook) internal view returns (IJB721TiersHookStore) {
        return IJB721TiersHook(hook).STORE();
    }

    /// @notice The banny body and outfit SVG files.
    /// @param hook The 721 contract that the product belongs to.
    /// @param upc The universal product code of the product that the SVG contents represent.
    function _svgOf(address hook, uint256 upc) internal view returns (string memory) {
        // Keep a reference to the stored svg contents.
        string memory svgContents = _svgContentOf[upc];

        if (bytes(svgContents).length != 0) return svgContents;

        return string.concat(
            '<image href="',
            JBIpfsDecoder.decode({
                baseUri: svgBaseUri, hexString: _storeOf(hook).encodedIPFSUriOf({hook: hook, tierId: upc})
            }),
            '" width="400" height="400"/>'
        );
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Dress your banny body with outfits and a background.
    /// @dev Decoration is allowed when ALL of the following hold:
    ///
    /// 1. The caller owns the banny body (via `_checkIfSenderIsOwner`).
    /// 2. The banny body is not currently locked (`outfitLockedUntil` has not yet passed).
    /// 3. For each outfit supplied:
    ///    a. The caller is the outfit's current owner, OR
    ///    b. The outfit is currently worn by another banny body and the caller owns that banny body.
    ///    (If the outfit is unworn, only (a) applies — the outfit owner must be the caller.)
    /// 4. For the background supplied (if non-zero):
    ///    a. The caller is the background's current owner, OR
    ///    b. The background is currently used by another banny body and the caller owns that banny body.
    ///    (If the background is unused, only (a) applies — the background owner must be the caller.)
    /// 5. Outfit categories must be valid (within recognized range) and passed in ascending order.
    /// 6. Conflicting categories are rejected (e.g., a full head blocks individual face pieces;
    ///    a full suit blocks separate top/bottom).
    ///
    /// @param hook The hook storing the assets.
    /// @param bannyBodyId The ID of the banny body being dressed.
    /// @param backgroundId The ID of the background that'll be associated with the specified banny.
    /// @param outfitIds The IDs of the outfits that'll be associated with the specified banny. Only one outfit per
    /// outfit category allowed at a time and they must be passed in order.
    function decorateBannyWith(
        address hook,
        uint256 bannyBodyId,
        uint256 backgroundId,
        uint256[] calldata outfitIds
    )
        external
        override
        nonReentrant
    {
        _checkIfSenderIsOwner({hook: hook, upc: bannyBodyId});

        // Can't decorate a banny that's locked.
        if (outfitLockedUntil[hook][bannyBodyId] > block.timestamp) {
            revert Banny721TokenUriResolver_OutfitChangesLocked();
        }

        emit DecorateBanny({
            hook: hook, bannyBodyId: bannyBodyId, backgroundId: backgroundId, outfitIds: outfitIds, caller: _msgSender()
        });

        // Add the background.
        _decorateBannyWithBackground({hook: hook, bannyBodyId: bannyBodyId, backgroundId: backgroundId});

        // Add the outfits.
        _decorateBannyWithOutfits({hook: hook, bannyBodyId: bannyBodyId, outfitIds: outfitIds});
    }

    /// @notice Locks a banny body ID so that it can't change its outfit for a period of time.
    /// @param hook The hook address of the collection.
    /// @param bannyBodyId The ID of the banny body to lock.
    function lockOutfitChangesFor(address hook, uint256 bannyBodyId) public override {
        // Make sure only the banny body's owner can lock it.
        _checkIfSenderIsOwner({hook: hook, upc: bannyBodyId});

        // Keep a reference to the current lock.
        uint256 currentLockedUntil = outfitLockedUntil[hook][bannyBodyId];

        // Calculate the new time at which the lock will expire.
        uint256 newLockUntil = block.timestamp + _LOCK_DURATION;

        // Make sure the new lock is at least as big as the current lock.
        if (currentLockedUntil > newLockUntil) revert Banny721TokenUriResolver_CantAccelerateTheLock();

        // Set the lock.
        outfitLockedUntil[hook][bannyBodyId] = newLockUntil;
    }

    /// @dev Make sure tokens can be received if the transaction was initiated by this contract.
    /// @param operator The address that initiated the transaction.
    /// @param from The address that initiated the transfer.
    /// @param tokenId The ID of the token being transferred.
    /// @param data The data of the transfer.
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    )
        external
        view
        override
        returns (bytes4)
    {
        from; // unused.
        tokenId; // unused.
        data; // unused.

        // Make sure the transaction's operator is this contract.
        if (operator != address(this)) revert Banny721TokenUriResolver_UnauthorizedTransfer();

        return IERC721Receiver.onERC721Received.selector;
    }

    /// @notice Allows the owner to set the product's name.
    /// @param upcs The universal product codes of the products having their name stored.
    /// @param names The names of the products.
    function setProductNames(uint256[] memory upcs, string[] memory names) external override onlyOwner {
        for (uint256 i; i < upcs.length; i++) {
            uint256 upc = upcs[i];
            string memory name = names[i];

            _customProductNameOf[upc] = name;

            emit SetProductName({upc: upc, name: name, caller: msg.sender});
        }
    }

    /// @notice Allows the owner of this contract to set the token metadata description, external URL, and SVG base URI.
    /// @param description The description to use in token metadata.
    /// @param url The external URL to use in token metadata.
    /// @param baseUri The base URI of the SVG files.
    function setMetadata(
        string calldata description,
        string calldata url,
        string calldata baseUri
    )
        external
        override
        onlyOwner
    {
        svgDescription = description;
        svgExternalUrl = url;
        svgBaseUri = baseUri;

        emit SetMetadata({description: description, externalUrl: url, baseUri: baseUri, caller: msg.sender});
    }

    /// @notice The owner of this contract can store SVG files for product IDs.
    /// @param upcs The universal product codes of the products having SVGs stored.
    /// @param svgContents The svg contents being stored, not including the parent <svg></svg> element.
    function setSvgContentsOf(uint256[] memory upcs, string[] calldata svgContents) external override {
        for (uint256 i; i < upcs.length; i++) {
            uint256 upc = upcs[i];
            string memory svgContent = svgContents[i];

            // Make sure there isn't already contents for the specified universal product code.
            if (bytes(_svgContentOf[upc]).length != 0) revert Banny721TokenUriResolver_ContentsAlreadyStored();

            // Get the stored svg hash for the product.
            bytes32 svgHash = svgHashOf[upc];

            // Make sure a hash exists.
            if (svgHash == bytes32(0)) revert Banny721TokenUriResolver_HashNotFound();

            // Make sure the content matches the hash.
            if (keccak256(abi.encodePacked(svgContent)) != svgHash) revert Banny721TokenUriResolver_ContentsMismatch();

            // Store the svg contents.
            _svgContentOf[upc] = svgContent;

            emit SetSvgContent({upc: upc, svgContent: svgContent, caller: msg.sender});
        }
    }

    /// @notice Allows the owner of this contract to upload the hash of an svg file for a universal product code.
    /// @dev This allows anyone to lazily upload the correct svg file.
    /// @param upcs The universal product codes of the products having SVG hashes stored.
    /// @param svgHashes The svg hashes being stored, not including the parent <svg></svg> element.
    function setSvgHashesOf(uint256[] memory upcs, bytes32[] memory svgHashes) external override onlyOwner {
        for (uint256 i; i < upcs.length; i++) {
            uint256 upc = upcs[i];
            bytes32 svgHash = svgHashes[i];

            // Make sure there isn't already contents for the specified universal product code.
            if (svgHashOf[upc] != bytes32(0)) revert Banny721TokenUriResolver_HashAlreadyStored();

            // Store the svg contents.
            svgHashOf[upc] = svgHash;

            emit SetSvgHash({upc: upc, svgHash: svgHash, caller: msg.sender});
        }
    }

    //*********************************************************************//
    // ---------------------- internal transactions ---------------------- //
    //*********************************************************************//

    /// @notice Add outfits to a banny body.
    /// @dev The caller must own the banny body being dressed and all outfits being worn.
    /// @param hook The hook storing the assets.
    /// @param bannyBodyId The ID of the banny body being dressed.
    /// @param outfitIds The IDs of the outfits that'll be associated with the specified banny. Only one outfit per
    /// outfit category allowed at a time and they must be passed in order.
    function _decorateBannyWithOutfits(address hook, uint256 bannyBodyId, uint256[] memory outfitIds) internal {
        // Keep track of certain outfits being used along the way to prevent conflicting outfits.
        bool hasHead;
        bool hasSuit;

        // Keep a reference to the category of the last outfit iterated on.
        uint256 lastAssetCategory;

        // Keep a reference to the currently attached outfits on the banny body.
        uint256[] memory previousOutfitIds = _attachedOutfitIdsOf[hook][bannyBodyId];

        // Keep a index counter that'll help with tracking progress.
        uint256 previousOutfitIndex;

        // Keep a reference to the previous outfit being iterated on when removing.
        uint256 previousOutfitId;

        // Get the outfit's product info.
        uint256 previousOutfitProductCategory;

        // Set the previous values if there are previous outfits.
        if (previousOutfitIds.length > 0) {
            previousOutfitId = previousOutfitIds[0];
            previousOutfitProductCategory = _productOfTokenId({hook: hook, tokenId: previousOutfitId}).category;
        }

        // Iterate through each outfit, transfering them in and adding them to the banny if needed, while transfering
        // out and removing old outfits no longer being worn.
        for (uint256 i; i < outfitIds.length; i++) {
            // Set the outfit ID being iterated on.
            uint256 outfitId = outfitIds[i];

            // Check if the call is being made either by the outfit's owner or the owner of the banny body currently
            // wearing it.
            if (_msgSender() != IERC721(hook).ownerOf(outfitId)) {
                // Get the banny body currently wearing this outfit.
                uint256 wearerId = wearerOf({hook: hook, outfitId: outfitId});

                // If the outfit is not currently worn, only the outfit's owner can use it for decoration.
                if (wearerId == 0) revert Banny721TokenUriResolver_UnauthorizedOutfit();

                // If the outfit is worn, the banny body's owner can also authorize its use.
                if (_msgSender() != IERC721(hook).ownerOf(wearerId)) {
                    revert Banny721TokenUriResolver_UnauthorizedOutfit();
                }
            }

            // Get the outfit's product info.
            uint256 outfitProductCategory = _productOfTokenId({hook: hook, tokenId: outfitId}).category;

            // The product's category must be a known category.
            if (outfitProductCategory < _BACKSIDE_CATEGORY || outfitProductCategory > _SPECIAL_BODY_CATEGORY) {
                revert Banny721TokenUriResolver_UnrecognizedCategory();
            }

            // Make sure the category is an increment of the previous outfit's category.
            if (i != 0 && outfitProductCategory <= lastAssetCategory) {
                revert Banny721TokenUriResolver_UnorderedCategories();
            }

            if (outfitProductCategory == _HEAD_CATEGORY) {
                hasHead = true;
            } else if (outfitProductCategory == _SUIT_CATEGORY) {
                hasSuit = true;
            } else if (
                (outfitProductCategory == _EYES_CATEGORY
                        || outfitProductCategory == _GLASSES_CATEGORY
                        || outfitProductCategory == _MOUTH_CATEGORY
                        || outfitProductCategory == _HEADTOP_CATEGORY) && hasHead
            ) {
                revert Banny721TokenUriResolver_HeadAlreadyAdded();
            } else if (
                (outfitProductCategory == _SUIT_TOP_CATEGORY || outfitProductCategory == _SUIT_BOTTOM_CATEGORY)
                    && hasSuit
            ) {
                revert Banny721TokenUriResolver_SuitAlreadyAdded();
            }

            // Remove all previous assets up to and including the current category being iterated on.
            // This inner loop advances through `previousOutfitIds` (bounded by outfit category count) and
            // terminates when it passes the current category or exhausts the array.
            while (previousOutfitProductCategory <= outfitProductCategory && previousOutfitProductCategory != 0) {
                // Transfer the previous outfit to the owner of the banny if its not being worn.
                // `_attachedOutfitIdsOf` hasnt been called yet, so the wearer should still be the banny body being
                // decorated.
                if (previousOutfitId != outfitId && wearerOf({hook: hook, outfitId: previousOutfitId}) == bannyBodyId) {
                    // slither-disable-next-line reentrancy-no-eth
                    _transferFrom({hook: hook, from: address(this), to: _msgSender(), assetId: previousOutfitId});
                }

                if (++previousOutfitIndex < previousOutfitIds.length) {
                    // set the next previous outfit.
                    previousOutfitId = previousOutfitIds[previousOutfitIndex];
                    // Get the next previous outfit.
                    previousOutfitProductCategory = _productOfTokenId({hook: hook, tokenId: previousOutfitId}).category;
                } else {
                    previousOutfitId = 0;
                    previousOutfitProductCategory = 0;
                }
            }

            // If the outfit is not already being worn by the banny, transfer it to this contract.
            if (wearerOf({hook: hook, outfitId: outfitId}) != bannyBodyId) {
                // Store the banny that's in the background.
                _wearerOf[hook][outfitId] = bannyBodyId;

                // Transfer the outfit to this contract.
                // slither-disable-next-line reentrancy-no-eth
                if (IERC721(hook).ownerOf(outfitId) != address(this)) {
                    _transferFrom({hook: hook, from: _msgSender(), to: address(this), assetId: outfitId});
                }
            }

            // Keep a reference to the last outfit's category.
            lastAssetCategory = outfitProductCategory;
        }

        // Remove and transfer out any remaining assets no longer being worn.
        // This loop is bounded by `previousOutfitIds.length`, which equals the number of outfits previously
        // attached to this banny. Since only one outfit per category is allowed, this is bounded by the number of
        // outfit categories (a small, fixed set).
        while (previousOutfitId != 0) {
            // `_attachedOutfitIdsOf` hasnt been called yet, so the wearer should still be the banny body being
            // decorated.
            if (wearerOf({hook: hook, outfitId: previousOutfitId}) == bannyBodyId) {
                // slither-disable-next-line reentrancy-no-eth
                _transferFrom({hook: hook, from: address(this), to: _msgSender(), assetId: previousOutfitId});
            }

            if (++previousOutfitIndex < previousOutfitIds.length) {
                // remove previous product.
                previousOutfitId = previousOutfitIds[previousOutfitIndex];
            } else {
                previousOutfitId = 0;
            }
        }

        // Store the outfits.
        _attachedOutfitIdsOf[hook][bannyBodyId] = outfitIds;
    }

    /// @notice Add a background to a banny body.
    /// @param hook The hook storing the assets.
    /// @param bannyBodyId The ID of the banny body being dressed.
    /// @param backgroundId The ID of the background that'll be associated with the specified banny.
    function _decorateBannyWithBackground(address hook, uint256 bannyBodyId, uint256 backgroundId) internal {
        // Keep a reference to the previous background attached.
        uint256 previousBackgroundId = _attachedBackgroundIdOf[hook][bannyBodyId];

        // Keep a reference to the user of the previous background.
        uint256 userOfPreviousBackground = userOf({hook: hook, backgroundId: previousBackgroundId});

        // If the background is changing, add the latest background and transfer the old one back to the owner.
        if (backgroundId != previousBackgroundId || userOfPreviousBackground != bannyBodyId) {
            // If there's a previous background worn by this banny, transfer it back to the owner.
            if (userOfPreviousBackground == bannyBodyId) {
                // Transfer the previous background to the owner of the banny.
                _transferFrom({hook: hook, from: address(this), to: _msgSender(), assetId: previousBackgroundId});
            }

            // Add the background if needed.
            if (backgroundId != 0) {
                // Keep a reference to the background's owner.
                address owner = IERC721(hook).ownerOf(backgroundId);

                // Check if the call is being made by the background's owner, or the owner of a banny body using it.
                if (_msgSender() != owner) {
                    // Get the banny body currently using this background.
                    uint256 userId = userOf({hook: hook, backgroundId: backgroundId});

                    // If the background is not currently used, only the background's owner can use it for decoration.
                    if (userId == 0) revert Banny721TokenUriResolver_UnauthorizedBackground();

                    // If the background is used, the banny body's owner can also authorize its use.
                    if (_msgSender() != IERC721(hook).ownerOf(userId)) {
                        revert Banny721TokenUriResolver_UnauthorizedBackground();
                    }
                }

                // Get the background's product info.
                JB721Tier memory backgroundProduct = _productOfTokenId({hook: hook, tokenId: backgroundId});

                // Background must exist and must be a background category.
                if (backgroundProduct.id == 0 || backgroundProduct.category != _BACKGROUND_CATEGORY) {
                    revert Banny721TokenUriResolver_UnrecognizedBackground();
                }

                // Store the background for the banny.
                // slither-disable-next-line reentrancy-no-eth
                _attachedBackgroundIdOf[hook][bannyBodyId] = backgroundId;

                // Store the banny that's in the background.
                // slither-disable-next-line reentrancy-no-eth
                _userOf[hook][backgroundId] = bannyBodyId;

                // Transfer the background to this contract if it's not already owned by this contract.
                if (owner != address(this)) {
                    _transferFrom({hook: hook, from: _msgSender(), to: address(this), assetId: backgroundId});
                }
            } else {
                // slither-disable-next-line reentrancy-no-eth
                _attachedBackgroundIdOf[hook][bannyBodyId] = 0;
            }
        }
    }

    /// @notice Transfer a token from one address to another.
    /// @param hook The 721 contract of the token being transferred.
    /// @param from The address to transfer the token from.
    /// @param to The address to transfer the token to.
    /// @param assetId The ID of the token to transfer.
    function _transferFrom(address hook, address from, address to, uint256 assetId) internal {
        IERC721(hook).safeTransferFrom({from: from, to: to, tokenId: assetId});
    }
}
