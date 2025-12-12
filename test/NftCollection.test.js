const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NftCollection", function () {
    let Nft, nft, owner, addr1, addr2, addr3;

    const NAME = "BuddiNFT";
    const SYMBOL = "BNFT";
    const MAX_SUPPLY = 5;
    const BASE_URI = "https://example.com/metadata/";

    beforeEach(async () => {
        [owner, addr1, addr2, addr3] = await ethers.getSigners();

        Nft = await ethers.getContractFactory("NftCollection");
        nft = await Nft.deploy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI);

        // Ethers v6 replaces nft.deployed() with:
        await nft.waitForDeployment();
    });

    it("initializes correctly", async () => {
        expect(await nft.name()).to.equal(NAME);
        expect(await nft.symbol()).to.equal(SYMBOL);
        expect(await nft.maxSupply()).to.equal(MAX_SUPPLY);
        expect(await nft.totalSupply()).to.equal(0);
    });

    it("only owner can mint", async () => {
        await expect(
            nft.connect(addr1).safeMint(addr1.address, 1)
        ).to.be.reverted;

        await expect(nft.safeMint(addr1.address, 1))
        .to.emit(nft, "Transfer")
        .withArgs(
            ethers.ZeroAddress,
            addr1.address,
            1
        );

        expect(await nft.totalSupply()).to.equal(1);
        expect(await nft.balanceOf(addr1.address)).to.equal(1);
        expect(await nft.ownerOf(1)).to.equal(addr1.address);
    });

    it("prevents double minting", async () => {
        await nft.safeMint(addr1.address, 2);
        await expect(nft.safeMint(addr2.address, 2))
        .to.be.revertedWithCustomError(nft, "TokenAlreadyMinted");
    });

    it("prevents minting beyond max supply", async () => {
        await nft.safeMint(addr1.address, 1);
        await nft.safeMint(addr1.address, 2);
        await nft.safeMint(addr1.address, 3);
        await nft.safeMint(addr1.address, 4);
        await nft.safeMint(addr1.address, 5);

        await expect(nft.safeMint(addr1.address, 6))
        .to.be.revertedWithCustomError(nft, "MaxSupplyReached");
    });

    it("transfers work and approvals work", async () => {
        await nft.safeMint(addr1.address, 10);

        // approve addr2
        await expect(nft.connect(addr1).approve(addr2.address, 10))
        .to.emit(nft, "Approval")
        .withArgs(addr1.address, addr2.address, 10);

        // addr2 transfers
        await expect(
            nft.connect(addr2).transferFrom(addr1.address, addr3.address, 10)
        )
        .to.emit(nft, "Transfer")
        .withArgs(addr1.address, addr3.address, 10);

        // operator approval
        await nft.safeMint(addr1.address, 11);
        await expect(nft.connect(addr1).setApprovalForAll(addr2.address, true))
        .to.emit(nft, "ApprovalForAll")
        .withArgs(addr1.address, addr2.address, true);

        // operator transfers
        await expect(
            nft.connect(addr2).transferFrom(addr1.address, addr3.address, 11)
        )
        .to.emit(nft, "Transfer")
        .withArgs(addr1.address, addr3.address, 11);
    });

    it("tokenURI works and rejects non-existent token", async () => {
        await nft.safeMint(addr1.address, 20);
        expect(await nft.tokenURI(20)).to.equal(BASE_URI + "20");
        await expect(nft.tokenURI(999)).to.be.reverted;
    });

    it("pause + unpause minting works", async () => {
        await nft.pause();
        await expect(nft.safeMint(addr1.address, 100)).to.be.reverted;
        await nft.unpause();
        await expect(nft.safeMint(addr1.address, 100))
        .to.emit(nft, "Transfer");
    });

    it("burn works and updates balances + totalSupply", async () => {
        await nft.safeMint(addr1.address, 50);

        expect(await nft.totalSupply()).to.equal(1);
        expect(await nft.balanceOf(addr1.address)).to.equal(1);

        await expect(nft.connect(addr1).burn(50))
        .to.emit(nft, "Transfer")
        .withArgs(addr1.address, ethers.ZeroAddress, 50);

        expect(await nft.totalSupply()).to.equal(0);
        await expect(nft.ownerOf(50)).to.be.reverted;
    });

    it("rejects mint to zero address", async () => {
        await expect(
            nft.safeMint(ethers.ZeroAddress, 1)
        ).to.be.revertedWithCustomError(nft, "ZeroAddress");
    });

    it("gas: mint + transfer stays within bounds", async () => {
        const tx1 = await nft.safeMint(addr1.address, 77);
        const receipt1 = await tx1.wait();
        const tx2 = await nft.connect(addr1).transferFrom(addr1.address, addr2.address, 77);
        const receipt2 = await tx2.wait();

        expect(receipt1.gasUsed).to.be.lessThan(300000n);
        expect(receipt2.gasUsed).to.be.lessThan(200000n);
    });
});
