const truffleAssert = require('truffle-assertions');
const Erc20 = artifacts.require("Erc20");

contract("Erc20", (accounts) => {
    let token;
    let owner;
    let user;
    const initTokensNum = 10;

    beforeEach(async function() {
        [owner, user] = accounts;
        token = await Erc20.new("test", "TST", owner, initTokensNum);
    });

    it("should allow to transfer tokens", async () => {
        // Try to transfer 0 tokens
        await truffleAssert.reverts(
            token.transfer(user, 0),
            "Incorrect value for transaction!" 
        );
        // Try to transfer tokens from bankrupt
        await truffleAssert.reverts(
            token.transfer(owner, 5, {from: user}),
            "Not enough tokens!"
        );

        const tokensToTransfer = 3;
        const transfer = await token.transfer(user, tokensToTransfer);
        truffleAssert.eventEmitted(transfer, 'Transfer', (ev) => {
            return ev._from == owner && ev._to == user && ev._value == tokensToTransfer;
        }, "transfer should trigger correct 'Transfer' event.");
        expect((await token.balanceOf(owner)).toNumber()).to.eq(initTokensNum - tokensToTransfer);
        expect((await token.balanceOf(user)).toNumber()).to.eq(tokensToTransfer);
    });

    it("should allow to approve tokens withdraw", async () => {
        const tokensToApprove = 3;
        const approve = await token.approve(user, tokensToApprove);
        truffleAssert.eventEmitted(approve, 'Approve', (ev) => {
            return ev._sender == owner && ev._spender == user && ev._value == tokensToApprove;
        }, "approve should trigger correct 'Approve' event.");
        expect((await token.allowance(owner, user)).toNumber()).to.eq(tokensToApprove);
    });

    it("should allow to transfer approved tokens", async () => {
        // Try to transfer 0 tokens
        await truffleAssert.reverts(
            token.transferFrom(owner, user, 0),
            "Incorrect value for transaction!" 
        );
        // Try to transfer tokens from bankrupt
        await truffleAssert.reverts(
            token.transferFrom(user, owner, 5),
            "Not enough tokens!"
        );

        const tokensToTransfer = 3;

        // Fails if not approved
        await truffleAssert.reverts(
            token.transferFrom(owner, user, tokensToTransfer, {from: user}),
            "No allowance provided for this transaction!" 
        );

        // Approve
        const tokensToApprove = 6;
        await token.approve(user, tokensToApprove);

        // Transfer
        const transfer = await token.transferFrom(owner, user, tokensToTransfer, {from: user});
        truffleAssert.eventEmitted(transfer, 'Transfer', (ev) => {
            return ev._from == owner && ev._to == user && ev._value == tokensToTransfer;
        }, "transferFrom should trigger correct 'Transfer' event.");
        expect((await token.balanceOf(owner)).toNumber()).to.eq(initTokensNum - tokensToTransfer);
        expect((await token.balanceOf(user)).toNumber()).to.eq(tokensToTransfer);
        expect((await token.allowance(owner, user)).toNumber()).to.eq(tokensToApprove - tokensToTransfer);
    });


    it("should allow to mint new tokens", async () => {
        const tokensToMint = 20;

        // Non owner call fails
        await truffleAssert.reverts(
            token.mint(owner, tokensToMint, {from: user}),
            "This operation is allowed only for owner!" 
        );

        // Mint
        const mint = await token.mint(owner, tokensToMint);
        truffleAssert.eventEmitted(mint, 'Transfer', (ev) => {
            return ev._from == "0x0000000000000000000000000000000000000000" && ev._to == owner && ev._value == tokensToMint;
        }, "mint should trigger correct 'Transfer' event.");
        expect((await token.balanceOf(owner)).toNumber()).to.eq(initTokensNum + tokensToMint);
        expect((await token.totalSupply()).toNumber()).to.eq(initTokensNum + tokensToMint);
    });
});