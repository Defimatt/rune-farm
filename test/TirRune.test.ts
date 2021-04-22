import { ethers } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";

chai.use(solidity);
const { expect } = chai;

import { TirRune } from "../typechain/TirRune";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ContractFactory } from "@ethersproject/contracts";

describe("TirRune", async() => {
    let TirRuneFactory: ContractFactory;
    let TirRune: TirRune;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let dev: SignerWithAddress;
    let vault: SignerWithAddress;
    let charity: SignerWithAddress;
    let bot: SignerWithAddress;
    let TirRuneAsAlice: TirRune;

    const zeroAddress = "0x0000000000000000000000000000000000000000";
    const mintSignature = "mint(address,uint256)";

    before(async() => {   
        const signers = await ethers.getSigners();
        alice = signers[0];
        bob = signers[1];
        dev = signers[2];
        vault = signers[3];
        charity = signers[4];
        bot = signers[5];

        TirRuneFactory = await ethers.getContractFactory("TirRune", dev);
    });

    beforeEach(async() => {
        TirRune = (await TirRuneFactory.deploy()) as TirRune;
        await TirRune.deployed();
        TirRuneAsAlice = TirRune.connect(alice);
    });

    it("should have the correct name", async() => {
        expect(await TirRune.name()).to.equal("Tir");
    });

    it("should have the correct symbol", async() => {
        expect(await TirRune.symbol()).to.equal("TIR");
    });

    it("should have the correct decimals", async() => {
        expect(await TirRune.decimals()).to.equal(18);
    });

    it("should allow owner to mint token", async() => {
        await TirRune[mintSignature].call(null, alice.address, 1000);
        expect(await TirRune.totalSupply()).to.equal(1000);
        expect(await TirRune.balanceOf(alice.address)).to.equal(1000);
        expect(await TirRune.balanceOf(bob.address)).to.equal(0);

        await TirRune[mintSignature].call(null, bob.address, 1);
        expect(await TirRune.totalSupply()).to.equal(1001);
        expect(await TirRune.balanceOf(alice.address)).to.equal(1000);
        expect(await TirRune.balanceOf(bob.address)).to.equal(1);
    });

    it("should not allow non-owner to mint token", async() => {
        
        await expect(TirRuneAsAlice[mintSignature].call(null, alice.address, 1000)).to.be.revertedWith("Ownable: caller is not the owner");

        expect(await TirRune.totalSupply()).to.equal(0);
        expect(await TirRune.balanceOf(alice.address)).to.equal(0);
        expect(await TirRune.balanceOf(bob.address)).to.equal(0);
    });

    it("should not allow non-owner to set the dev address", async() => {
        expect(await TirRune.devAddress()).to.equal(zeroAddress);
        await expect(TirRuneAsAlice.setDevAddress(bob.address)).to.be.reverted;
    });

    it("should allow owner to set the dev address", async() => {
        expect(await TirRune.devAddress()).to.equal(zeroAddress);
        await TirRune.setDevAddress(dev.address);
        expect(await TirRune.devAddress()).to.equal(dev.address);
    });

    it("should not allow non-dev to stop minting", async() => {
        expect(await TirRune.mintable()).to.equal(true);

        await expect(TirRuneAsAlice.disableMintingForever()).to.be.revertedWith("dev: wut?");

        expect(await TirRune.mintable()).to.equal(true);
    });

    it("should allow dev to stop minting", async() => {
        await TirRune.setDevAddress(dev.address);

        expect(await TirRune.totalSupply()).to.equal(0);
        expect(await TirRune.mintable()).to.equal(true);

        await TirRune.disableMintingForever();

        expect(await TirRune.mintable()).to.equal(false);
        await expect(TirRune[mintSignature].call(null, alice.address, 1000)).to.be.revertedWith("Minting has been forever disabled");
        expect(await TirRune.totalSupply()).to.equal(0);
    });

    it("should not allow non-dev to set fees", async() => {
        await TirRune.setDevAddress(dev.address);

        await expect(TirRuneAsAlice.setFeeInfo(vault.address, charity.address, dev.address, bot.address, 100, 10, 10, 2000)).to.be.revertedWith("dev: wut?");
    });

    it("should allow dev to set fees", async() => {
        expect(await TirRune.vaultFee()).to.equal(0);
        expect(await TirRune.charityFee()).to.equal(0);
        expect(await TirRune.devFee()).to.equal(0);
        expect(await TirRune.botFee()).to.equal(0);

        await TirRune.setDevAddress(dev.address);
        await TirRune.setFeeInfo(vault.address, charity.address, dev.address, bot.address, 100, 10, 10, 2000);

        expect(await TirRune.vaultFee()).to.equal(100);
        expect(await TirRune.charityFee()).to.equal(10);
        expect(await TirRune.devFee()).to.equal(10);
        expect(await TirRune.botFee()).to.equal(2000);
    });
});