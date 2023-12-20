// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {UserFactory} from "test/lib/UserFactory.sol";
import {ModuleTestFixtureGenerator} from "test/lib/ModuleTestFixtureGenerator.sol";

import {MockERC20, ERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {FullMath} from "libraries/FullMath.sol";
import {MockPriceFeed} from "test/mocks/MockPriceFeed.sol";
import {MockBalancerWeightedPool} from "test/mocks/MockBalancerPool.sol";
import {MockBalancerVault} from "test/mocks/MockBalancerVault.sol";
import {MockUniV3Pair} from "test/mocks/MockUniV3Pair.sol";

import "modules/PRICE/OlympusPrice.v2.sol";
import {ChainlinkPriceFeeds} from "modules/PRICE/submodules/feeds/ChainlinkPriceFeeds.sol";
import {UniswapV3Price} from "modules/PRICE/submodules/feeds/UniswapV3Price.sol";
import {BalancerPoolTokenPrice, IVault, IWeightedPool} from "modules/PRICE/submodules/feeds/BalancerPoolTokenPrice.sol";
import {SimplePriceFeedStrategy} from "modules/PRICE/submodules/strategies/SimplePriceFeedStrategy.sol";

// Tests for OlympusPrice v2
//
// Asset Information
// [X] getAssets - returns all assets configured on the PRICE module
//      [X] zero assets
//      [X] one asset
//      [X] many assets
// [X] getAssetData - returns the price configuration data for a given asset
//
// Asset Prices
// [X] getPrice(address, Variant) - returns the price of an asset in terms of the unit of account (USD)
//      [X] current variant - dynamically calculates price from strategy and components
//           [X] no strategy submodule (only one price source)
//              [X] single price feed
//              [X] single price feed with recursive calls
//              [X] reverts if price is zero
//           [X] with strategy submodule
//              [X] two feeds (two separate feeds)
//              [X] two feeds (one feed + MA)
//              [X] three feeds (three separate feeds)
//              [X] three feeds (two feeds + MA)
//              [X] reverts if strategy fails
//              [X] reverts if price is zero
//           [X] reverts if no address is given
//      [X] last variant - loads price from cache
//           [X] single observation stored
//           [X] multiple observations stored
//           [X] multiple observations stored, nextObsIndex != 0
//           [X] reverts if asset not configured
//           [X] reverts if no address is given
//      [X] moving average variant - returns the moving average from stored observations
//           [X] single observation stored
//           [X] multiple observations stored
//           [X] reverts if moving average isn't stored
//           [X] reverts if asset not configured
//           [X] reverts if no address is given
//      [X] reverts if invalid variant provided
//      [X] reverts if asset not configured on PRICE module (not approved)
// [X] getPrice(address) - convenience function for current price
//      [X] returns cached value if updated this timestamp
//      [X] calculates and returns current price if not updated this timestamp
//      [X] reverts if asset not configured on PRICE module (not approved)
// [X] getPrice(address, uint48) - convenience function for price up to a certain age
//      [X] returns cached value if updated within the provided age
//      [X] calculates and returns current price if not updated within the provided age
//      [X] reverts if asset not configured on PRICE module (not approved)
// [X] getPriceIn(asset, base, Variant) - returns the price of an asset in terms of another asset
//      [X] current variant - dynamically calculates price from strategy and components
//      [X] last variant - loads price from cache
//      [X] moving average variant - returns the moving average from stored observations
//      [X] reverts if invalid variant provided for either asset
//      [X] reverts if either asset price is zero
//      [X] reverts if either asset is not configured on PRICE module (not approved)
// [X] getPriceIn(asset, base) - returns cached value if updated this timestamp, otherwise calculates dynamically
//      [X] returns cached value if both assets updated this timestamp
//      [X] calculates and returns current price if either asset not updated this timestamp
// [X] getPriceIn(asset, base, uint48) - returns cached value if updated within the provided age, otherwise calculates dynamically
//      [X] returns cached value if both assets updated within the provided age
//      [X] calculates and returns current price if either asset not updated within the provided age
// [X] storePrice - caches the price of an asset (stores a new observation if the asset uses a moving average)
//      [X] reverts if asset not configured on PRICE module (not approved)
//      [X] reverts if price is zero
//      [X] reverts if caller is not permissioned
//      [X] updates stored observations
//           [X] single observation stored (no moving average)
//           [X] multiple observations stored (moving average configured)
//      [X] price stored event emitted
//
// Asset Management
// [X] addAsset - add an asset to the PRICE module
//      [X] reverts if asset already configured (approved)
//      [X] reverts if asset address is not a contract
//      [X] reverts if no strategy is set, moving average is disabled and multiple feeds (MA + feeds > 1)
//      [X] reverts if no strategy is set, moving average is enabled and single feed (MA + feeds > 1)
//      [X] reverts if caller is not permissioned
//      [X] reverts if moving average is used, but not stored
//      [X] reverts if a non-functioning configuration is provided
//      [X] all asset data is stored correctly
//      [X] asset added to assets array
//      [X] asset added with no strategy, moving average disabled, single feed
//      [X] asset added with strategy, moving average enabled, single feed
//      [X] asset added with strategy, moving average enabled, mutiple feeds
//      [X] reverts if moving average contains any zero observations
//      [X] if not storing moving average and no cached value provided, dynamically calculates cache and stores so no zero cache values are stored
// [X] removeAsset
//      [X] reverts if asset not configured (not approved)
//      [X] reverts if caller is not permissioned
//      [X] all asset data is removed
//      [X] asset removed from assets array
// [X] updateAssetPriceFeeds
//      [X] reverts if asset not configured (not approved)
//      [X] reverts if caller is not permissioned
//      [X] reverts if no feeds are provided
//      [X] reverts if any feed is not installed as a submodule
//      [X] reverts if a non-functioning configuration is provided
//      [X] stores new feeds in asset data as abi-encoded bytes of the feed address array
// [X] updateAssetPriceStrategy
//      [X] reverts if asset not configured (not approved)
//      [X] reverts if caller is not permissioned
//      [X] reverts if strategy is not installed as a submodule
//      [X] reverts if uses moving average but moving average is not stored for asset
//      [X] reverts if no strategy is provided, but feeds > 1
//      [X] reverts if no strategy is provided, but MA + feeds > 1
//      [X] reverts if a non-functioning configuration is provided
//      [X] stores empty strategy when feeds = 1
//      [X] stores new strategy in asset data as abi-encoded bytes of the strategy component
// [X] updateAssetMovingAverage
//      [X] reverts if asset not configured (not approved)
//      [X] reverts if caller is not permissioned
//      [X] reverts if last observation time is in the future
//      [X] reverts if a non-functioning configuration is provided
//      [X] previous configuration and observations cleared
//      [X] if storing moving average
//           [X] reverts if moving average duration and observation frequency are invalid
//           [X] reverts if implied observations does not equal the amount of observations provided
//           [X] reverts if a zero value is provided
//           [X] if storeMovingAverage was previously enabled, stores moving average data, including observations, in asset data
//           [X] if storeMovingAverage was previously disabled, stores moving average data, including observations, in asset data
//      [X] if not storing moving average
//           [X] reverts if more than one observation is provided
//           [X] reverts if movingAverageDuration is provided
//           [X] one observation provided
//              [X] stores observation and last observation time in asset data
//              [X] reverts if a zero value is provided
//           [X] no observations provided
//              [X] stores last observation time in asset data
//              [X] calculates current price and stores as cached value

// In order to create the necessary configuration to test above scenarios, the following assets/feed combinations are created on the price module:
// - OHM: Three feed using the getMedianPriceIfDeviation strategy
// - RSV: Two feed using the getAveragePriceIfDeviation strategy
// - WETH: One feed with no strategy
// - ALPHA: One feed with no strategy
// - BPT: One feed (has recursive calls) with no strategy
// - ONEMA: One feed + MA using the getFirstNonZeroPrice strategy
// - TWOMA: Two feed + MA using the getAveragePrice strategy

contract PriceV2Test is Test {
    using FullMath for uint256;
    using ModuleTestFixtureGenerator for OlympusPricev2;

    MockPriceFeed internal ohmUsdPriceFeed;
    MockPriceFeed internal ohmEthPriceFeed;
    MockPriceFeed internal reserveUsdPriceFeed;
    MockPriceFeed internal reserveEthPriceFeed;
    MockPriceFeed internal ethUsdPriceFeed;
    MockPriceFeed internal alphaUsdPriceFeed;
    MockPriceFeed internal onemaUsdPriceFeed;
    MockPriceFeed internal twomaUsdPriceFeed;
    MockPriceFeed internal twomaEthPriceFeed;
    MockUniV3Pair internal ohmEthUniV3Pool;
    MockBalancerWeightedPool internal bpt;
    MockBalancerVault internal balVault;

    MockERC20 internal ohm;
    MockERC20 internal reserve;
    MockERC20 internal weth;
    MockERC20 internal alpha;
    MockERC20 internal onema;
    MockERC20 internal twoma;

    Kernel internal kernel;
    OlympusPricev2 internal price;
    ChainlinkPriceFeeds internal chainlinkPrice;
    BalancerPoolTokenPrice internal bptPrice;
    UniswapV3Price internal univ3Price;
    SimplePriceFeedStrategy internal strategy;

    address internal writer;

    int256 internal constant CHANGE_DECIMALS = 1e4;
    uint32 internal constant OBSERVATION_FREQUENCY = 8 hours;

    // Re-declare events from PRICE.v2.sol
    event PriceStored(address indexed asset_, uint256 price_, uint48 timestamp_);
    event AssetAdded(address indexed asset_);
    event AssetRemoved(address indexed asset_);
    event AssetPriceFeedsUpdated(address indexed asset_);
    event AssetPriceStrategyUpdated(address indexed asset_);
    event AssetMovingAverageUpdated(address indexed asset_);

    function setUp() public {
        vm.warp(51 * 365 * 24 * 60 * 60); // Set timestamp at roughly Jan 1, 2021 (51 years since Unix epoch)

        {
            // Deploy mocks for testing PRICEv2

            // Tokens
            ohm = new MockERC20("Olympus", "OHM", 9);
            reserve = new MockERC20("Reserve", "RSV", 18);
            weth = new MockERC20("Wrapped ETH", "WETH", 18);
            alpha = new MockERC20("Alpha", "ALPHA", 18);
            onema = new MockERC20("One + MA", "ONEMA", 18);
            twoma = new MockERC20("Two + MA", "TWOMA", 18);

            // Balancer
            bpt = new MockBalancerWeightedPool();
            bpt.setDecimals(18);
            bpt.setTotalSupply(1e24);
            uint256[] memory weights = new uint256[](2);
            weights[0] = 5e17;
            weights[1] = 5e17;
            bpt.setNormalizedWeights(weights);
            // Target price: 10 reserves per OHM, balances are 1e7 Reserve and 1e6 OHM
            // At 1 million LP token supply, LP price should be 20e18
            bpt.setInvariant(uint256(3.16227766016838e24));
            balVault = new MockBalancerVault();
            address[] memory tokens = new address[](2);
            tokens[0] = address(ohm);
            tokens[1] = address(reserve);
            balVault.setTokens(tokens);
            uint256[] memory balances = new uint256[](2);
            balances[0] = 1e6 * 1e9;
            balances[1] = 1e7 * 1e18;
            balVault.setBalances(balances);

            // Chainlink
            ethUsdPriceFeed = new MockPriceFeed();
            ethUsdPriceFeed.setDecimals(8);
            ethUsdPriceFeed.setLatestAnswer(int256(2000e8));
            ethUsdPriceFeed.setTimestamp(block.timestamp);
            ethUsdPriceFeed.setRoundId(1);
            ethUsdPriceFeed.setAnsweredInRound(1);

            alphaUsdPriceFeed = new MockPriceFeed();
            alphaUsdPriceFeed.setDecimals(8);
            alphaUsdPriceFeed.setLatestAnswer(int256(50e8));
            alphaUsdPriceFeed.setTimestamp(block.timestamp);
            alphaUsdPriceFeed.setRoundId(1);
            alphaUsdPriceFeed.setAnsweredInRound(1);

            ohmUsdPriceFeed = new MockPriceFeed();
            ohmUsdPriceFeed.setDecimals(8);
            ohmUsdPriceFeed.setLatestAnswer(int256(10e8));
            ohmUsdPriceFeed.setTimestamp(block.timestamp);
            ohmUsdPriceFeed.setRoundId(1);
            ohmUsdPriceFeed.setAnsweredInRound(1);

            ohmEthPriceFeed = new MockPriceFeed();
            ohmEthPriceFeed.setDecimals(18);
            ohmEthPriceFeed.setLatestAnswer(int256(0.005e18));
            ohmEthPriceFeed.setTimestamp(block.timestamp);
            ohmEthPriceFeed.setRoundId(1);
            ohmEthPriceFeed.setAnsweredInRound(1);

            reserveUsdPriceFeed = new MockPriceFeed();
            reserveUsdPriceFeed.setDecimals(8);
            reserveUsdPriceFeed.setLatestAnswer(int256(1e8));
            reserveUsdPriceFeed.setTimestamp(block.timestamp);
            reserveUsdPriceFeed.setRoundId(1);
            reserveUsdPriceFeed.setAnsweredInRound(1);

            reserveEthPriceFeed = new MockPriceFeed();
            reserveEthPriceFeed.setDecimals(18);
            reserveEthPriceFeed.setLatestAnswer(int256(0.0005e18));
            reserveEthPriceFeed.setTimestamp(block.timestamp);
            reserveEthPriceFeed.setRoundId(1);
            reserveEthPriceFeed.setAnsweredInRound(1);

            onemaUsdPriceFeed = new MockPriceFeed();
            onemaUsdPriceFeed.setDecimals(8);
            onemaUsdPriceFeed.setLatestAnswer(int256(5e8));
            onemaUsdPriceFeed.setTimestamp(block.timestamp);
            onemaUsdPriceFeed.setRoundId(1);
            onemaUsdPriceFeed.setAnsweredInRound(1);

            twomaUsdPriceFeed = new MockPriceFeed();
            twomaUsdPriceFeed.setDecimals(8);
            twomaUsdPriceFeed.setLatestAnswer(int256(20e8));
            twomaUsdPriceFeed.setTimestamp(block.timestamp);
            twomaUsdPriceFeed.setRoundId(1);
            twomaUsdPriceFeed.setAnsweredInRound(1);

            twomaEthPriceFeed = new MockPriceFeed();
            twomaEthPriceFeed.setDecimals(18);
            twomaEthPriceFeed.setLatestAnswer(int256(0.01e18));
            twomaEthPriceFeed.setTimestamp(block.timestamp);
            twomaEthPriceFeed.setRoundId(1);
            twomaEthPriceFeed.setAnsweredInRound(1);

            // UniswapV3
            ohmEthUniV3Pool = new MockUniV3Pair();
            bool ohmFirst = address(ohm) < address(weth);
            ohmEthUniV3Pool.setToken0(ohmFirst ? address(ohm) : address(weth));
            ohmEthUniV3Pool.setToken1(ohmFirst ? address(weth) : address(ohm));
            // Create ticks for a 60 second observation period
            // Set to a price of 1 OHM = 0.005 ETH
            // Weighted tick needs to be 154257 (if OHM is token0) or -154257 (if OHM is token1) (as if 5,000,000 ETH per OHM because of the decimal difference)
            // Therefore, we need a tick difference of 9255432 (if OHM is token0) or -9255432 (if OHM is token1)
            int56[] memory tickCumulatives = new int56[](2);
            tickCumulatives[0] = ohmFirst ? int56(100000000) : -int56(100000000);
            tickCumulatives[1] = ohmFirst ? int56(109255432) : -int56(109255432);
            ohmEthUniV3Pool.setTickCumulatives(tickCumulatives);
        }

        {
            // Deploy kernel
            kernel = new Kernel(); // this contract will be the executor

            // Deploy price module
            price = new OlympusPricev2(kernel, 18, OBSERVATION_FREQUENCY);

            // Deploy mock module writer
            writer = price.generateGodmodeFixture(type(OlympusPricev2).name);

            // Deploy price submodules
            chainlinkPrice = new ChainlinkPriceFeeds(price);
            bptPrice = new BalancerPoolTokenPrice(price, IVault(address(balVault)));
            strategy = new SimplePriceFeedStrategy(price);
            univ3Price = new UniswapV3Price(price);
        }

        {
            /// Initialize system and kernel
            kernel.executeAction(Actions.InstallModule, address(price));
            kernel.executeAction(Actions.ActivatePolicy, address(writer));

            // Install submodules on price module
            vm.startPrank(writer);
            price.installSubmodule(chainlinkPrice);
            price.installSubmodule(bptPrice);
            price.installSubmodule(univ3Price);
            price.installSubmodule(strategy);
            vm.stopPrank();
        }
    }

    function _addBaseAssets(uint256 nonce_) internal {
        // Configure price feed data and add asset to price module
        vm.startPrank(writer);

        // OHM - Three feeds using the getMedianPriceIfDeviation strategy
        {
            ChainlinkPriceFeeds.OneFeedParams memory ohmFeedOneParams = ChainlinkPriceFeeds
            .OneFeedParams(ohmUsdPriceFeed, uint48(24 hours));

            ChainlinkPriceFeeds.TwoFeedParams memory ohmFeedTwoParams = ChainlinkPriceFeeds
            .TwoFeedParams(
                ohmEthPriceFeed,
                uint48(24 hours),
                ethUsdPriceFeed,
                uint48(24 hours)
            );

            UniswapV3Price.UniswapV3Params memory ohmFeedThreeParams = UniswapV3Price
            .UniswapV3Params(ohmEthUniV3Pool, uint32(60 seconds), 0);

            PRICEv2.Component[] memory feeds = new PRICEv2.Component[](3);
            feeds[0] = PRICEv2.Component(
                toSubKeycode("PRICE.CHAINLINK"), // SubKeycode target
                ChainlinkPriceFeeds.getOneFeedPrice.selector, // bytes4 selector
                abi.encode(ohmFeedOneParams) // bytes memory params
            );
            feeds[1] = PRICEv2.Component(
                toSubKeycode("PRICE.CHAINLINK"), // SubKeycode target
                ChainlinkPriceFeeds.getTwoFeedPriceMul.selector, // bytes4 selector
                abi.encode(ohmFeedTwoParams) // bytes memory params
            );
            feeds[2] = PRICEv2.Component(
                toSubKeycode("PRICE.UNIV3"), // SubKeycode target
                UniswapV3Price.getTokenTWAP.selector, // bytes4 selector
                abi.encode(ohmFeedThreeParams) // bytes memory params
            );

            price.addAsset(
                address(ohm), // address asset_
                true, // bool storeMovingAverage_ // track OHM MA
                false, // bool useMovingAverage_ // do not use MA in strategy
                uint32(30 days), // uint32 movingAverageDuration_
                uint48(block.timestamp), // uint48 lastObservationTime_
                _makeRandomObservations(ohm, feeds[0], nonce_, uint256(90)), // uint256[] memory observations_
                PRICEv2.Component(
                    toSubKeycode("PRICE.SIMPLESTRATEGY"),
                    SimplePriceFeedStrategy.getMedianPrice.selector,
                    abi.encode(uint256(300)) // 3% deviation
                ), // Component memory strategy_
                feeds // Component[] feeds_
            );

            PRICEv2.Asset memory receivedAsset = price.getAssetData(address(ohm));
        }

        vm.stopPrank();
    }

    function _makeRandomObservations(
        MockERC20 asset,
        PRICEv2.Component memory feed,
        uint256 nonce,
        uint256 numObs
    ) internal view returns (uint256[] memory) {

        // Get current price from feed
        (bool success, bytes memory data) = address(price.getSubmoduleForKeycode(feed.target))
        .staticcall(
            abi.encodeWithSelector(feed.selector, address(asset), price.decimals(), feed.params)
        );

        require(success, "Price feed call failed");
        int256 fetchedPrice = int256(abi.decode(data, (uint256)));

        /// Perform a random walk and create observations array
        uint256[] memory obs = new uint256[](numObs);
        int256 change; // percentage with two decimals

        for (uint256 i = numObs; i > 0; --i) {
            // Add current price to obs array
            obs[i - 1] = uint256(fetchedPrice);

            /// Calculate a random percentage change from -10% to + 10% using the nonce and observation number
            change = int256(uint256(keccak256(abi.encodePacked(nonce, i)))) % int256(1000);

            /// Calculate the new ohmEth price
            fetchedPrice = (fetchedPrice * (CHANGE_DECIMALS + change)) / CHANGE_DECIMALS;
        }

        return obs;
    }

    function testA() public {
//        uint256 nonce_ = 1;
//
        _addBaseAssets(1);
//
//        // Get the current price for the asset
//        (uint256 price_1, uint48 timestamp_1) = price.getPrice(
//            address(weth),
//            PRICEv2.Variant.CURRENT
//        );
//
//        (uint256 price_2, uint48 timestamp_2) = price.getPrice(
//            address(alpha),
//            PRICEv2.Variant.CURRENT
//        );
//
//        uint256[] memory expectedObservations = new uint256[](2);
//
//        expectedObservations[0] = price_1;
//        expectedObservations[1] = price_2;
//
//        vm.startPrank(writer);
//
//        price.updateAssetMovingAverage(
//            address(weth),
//            true, // Enable storeMovingAverage (previously enabled)
//            uint32(expectedObservations.length * 8 hours), // movingAverageDuration_
//            uint48(block.timestamp), // lastObservationTime_
//            expectedObservations // observations_
//        );
//
//        PRICEv2.Asset memory receivedAsset = price.getAssetData(address(weth));
//
//        console.log(receivedAsset.storeMovingAverage);
//        console.log(receivedAsset.movingAverageDuration);
//        console.log(receivedAsset.nextObsIndex);
//        console.log(receivedAsset.numObservations);
//        console.logUint(uint(receivedAsset.obs[0]));
//        console.logUint(uint(receivedAsset.obs[1]));
//        console.log(receivedAsset.cumulativeObs);

//        assertEq(receivedAsset.numObservations, observations.length);
//        assertEq(receivedAsset.lastObservationTime, uint48(block.timestamp));
//        assertEq(receivedAsset.cumulativeObs, 2e18 + 3e18); // Overwrites existing value
//        assertEq(receivedAsset.obs, observations); // Overwrites existing observations
//        assertEq(receivedAsset.obs.length, observations.length); // Overwrites existing observations

    }
}
