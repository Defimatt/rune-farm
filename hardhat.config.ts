import { HardhatUserConfig } from "hardhat/types";
import "solidity-coverage"

import "@nomiclabs/hardhat-waffle";
import "hardhat-typechain";

const config: HardhatUserConfig = {
    defaultNetwork: "hardhat",
    solidity: {
        compilers: [
            {version: "0.6.0", settings: {}},
            {version: "0.6.2", settings: {}},
            {version: "0.6.12", settings: {}},
        ],
        
    },
    networks: {
        hardhat: {},
        localhost: {
            url: "http://127.0.0.1:7545",
        },
        coverage: {
            url: "http://127.0.0.1:8555",
        },
    },
    paths: {
        sources: "./src",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts"
      },
};
export default config;
