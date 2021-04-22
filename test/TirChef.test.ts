import { ethers } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";

chai.use(solidity);
const { expect } = chai;

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ContractFactory } from "@ethersproject/contracts";

// Rune.farm contracts
import { TirChef } from "../typechain/TirChef" // Chef under test
import { TirRune } from "../typechain/TirRune"; // Reward rune
import { ElRune } from "../typechain/ElRune"; // Withdrawal rune
import { TirVoid } from "../typechain/TirVoid"; // Reward rune void

// Other contracts
import { BEP20Mock } from "../typechain/BEP20Mock"; // Mock for LPs

describe("TirChef", async() => {
    let TirChefFactory: ContractFactory;
    let TirChef: TirChef;

    let TirRuneFactory: ContractFactory;
    let TirRune: TirRune;

    let ElRuneFactory: ContractFactory;
    let ElRune: ElRune;

    let TirVoidFactory: ContractFactory;
    let TirVoid: TirVoid;

    let BEP20MockFactory: ContractFactory;
    let BEP20Mock: BEP20Mock;

    // Some addresses to play with
    // Alice, bob: users
    // Vault, charity, dev, bot: fee destinations
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let carol: SignerWithAddress;
    let dev: SignerWithAddress;
    let vault: SignerWithAddress;
    let charity: SignerWithAddress;
    let bot: SignerWithAddress;

    let TirChefAsAlice: TirChef; // Call functions as Alice (to test owner or dev only)

    before(async() => {   
        const signers = await ethers.getSigners();
        alice = signers[0];
        bob = signers[1];
        carol = signers[2];
        dev = signers[3];
        vault = signers[4];
        charity = signers[5];
        bot = signers[6];

        TirChefFactory = await ethers.getContractFactory("TirChef", dev);
        TirRuneFactory = await ethers.getContractFactory("TirRune", dev);
        ElRuneFactory = await ethers.getContractFactory("ElRune", dev);
        TirVoidFactory = await ethers.getContractFactory("TirVoid", dev);
        BEP20MockFactory = await ethers.getContractFactory("BEP20Mock", dev);
    });

    beforeEach(async() => {
        TirRune = (await TirRuneFactory.deploy()) as TirRune;
        await TirRune.deployed();

        ElRune = (await ElRuneFactory.deploy()) as ElRune;
        await ElRune.deployed();

        TirVoid = (await TirVoidFactory.deploy(
            TirRune.address, // _rune
            dev.address // _devAddress
        )) as TirVoid;
        await TirVoid.deployed();
        
        TirChef = (await TirChefFactory.deploy(
            TirRune.address, // _rune
            dev.address, // _devAddress
            vault.address, // _vaultAddress
            charity.address, // _charityAddress
            TirVoid.address, // _voidAddress
            1, // _runePerBlock
            100, // _startBlock
            ElRune.address // _withdrawFeeToken
        )) as TirChef;
        await TirChef.deployed();
        TirChefAsAlice = TirChef.connect(alice);
        
        // Give Tir to the Chef
        await TirRune.transferOwnership(TirChef.address);
    });

    it("should set correct state variables", async() => {
        expect(await TirChef.rune()).to.equal(TirRune.address);
        expect(await TirChef.devAddress()).to.equal(dev.address);
        expect(await TirChef.vaultAddress()).to.equal(vault.address);
        expect(await TirChef.charityAddress()).to.equal(charity.address);
        expect(await TirChef.voidAddress()).to.equal(TirVoid.address);
        expect(await TirChef.runePerBlock()).to.equal(1);
        expect(await TirChef.startBlock()).to.equal(100);
    });

    it("should default to zero fees", async() => {
        expect(await TirChef["devMintPercent()"]()).to.equal(0);
        expect(await TirChef["vaultMintPercent()"]()).to.equal(0);
        expect(await TirChef["charityMintPercent()"]()).to.equal(0);
        expect(await TirChef["devDepositPercent()"]()).to.equal(0);
        expect(await TirChef["vaultDepositPercent()"]()).to.equal(0);
        expect(await TirChef["charityDepositPercent()"]()).to.equal(0);
    });

    it("should default to zero pools", async() => {
        expect(await TirChef.poolLength()).to.equal(0);
    });

    context("With LP tokens added", async() => {
        let LP: BEP20Mock;
        let LPAsAlice: BEP20Mock;

        let LP2: BEP20Mock;
        let LP2AsAlice: BEP20Mock;

        beforeEach(async() => {
            LP = (await BEP20MockFactory.deploy("LPToken", "LP", 10000000000)) as BEP20Mock;
            LPAsAlice = LP.connect(alice);

            await LP.transfer(alice.address, 1000);
            await LP.transfer(bob.address, 1000);
            await LP.transfer(carol.address, 1000);

            LP2 = (await BEP20MockFactory.deploy("LPToken2", "LP2", 10000000000)) as BEP20Mock;
            LP2AsAlice = LP2.connect(alice);

            await LP2.transfer(alice.address, 1000);
            await LP2.transfer(bob.address, 1000);
            await LP2.transfer(carol.address, 1000);
        });

        it("should allow emergency withdraw", async() => {
            // Test 0% deposit fee
            await TirChef.add(100, LP.address, 0, true);

            await LPAsAlice.approve(TirChef.address, 1000);
            await TirChefAsAlice.deposit(0, 100);
            expect(await LP.balanceOf(alice.address)).to.equal(900);

            await TirChefAsAlice.emergencyWithdraw(0);
            expect(await LP.balanceOf(alice.address)).to.equal(1000);
            expect(await TirRune.balanceOf(alice.address)).to.equal(0); // Check no Tir rewards

            // Test 1% deposit fee
            await TirChef.add(100, LP2.address, 100, true);

            await LP2AsAlice.approve(TirChef.address, 1000);
            await TirChefAsAlice.deposit(1, 100);
            expect(await LP2.balanceOf(alice.address)).to.equal(900);
            
            await TirChefAsAlice.emergencyWithdraw(1);
            expect(await LP2.balanceOf(alice.address)).to.equal(999);
            expect(await TirRune.balanceOf(alice.address)).to.equal(0); // Check no Tir rewards
        });
    });

});