const truffleAssert = require('truffle-assertions');
const CharityExchanger = artifacts.require("CharityExchanger");
const CharityToken = artifacts.require("CharityToken");

contract("CharityExchanger", (accounts) => {
    const tokensOnDeploy = 300;
    let exchanger;
    let token;
    let owner;
    let buyer;

    beforeEach(async function() {
        [owner, buyer] = accounts;
        exchanger = await CharityExchanger.new();
        token = await CharityToken.at(await exchanger.token());
    });
    
    it("should have valid storage", async () => {
        expect(await exchanger.owner()).to.eq(owner);
        expect(await exchanger.token()).to.not.eq("0x0000000000000000000000000000000000000000");
    });

    it("should allow to buy and sell tokens", async () => {
        // Buy
        const tokensToBuy = 3;
        const tx = await exchanger.sendTransaction({value: tokensToBuy, from: buyer});
        truffleAssert.eventEmitted(tx, 'Buy', (ev) => {
            return ev._buyer == buyer && ev._value == tokensToBuy;
        }, "Receive should trigger correct 'Buy' event.");
        expect((await token.balanceOf(buyer)).toNumber()).to.eq(tokensToBuy);
        expect((await token.balanceOf(exchanger.address)).toNumber()).to.eq(tokensOnDeploy - tokensToBuy);

        // Approve
        const tokensToSell = 2;
        const approve = await token.approve(exchanger.address, tokensToSell, {from: buyer});
        truffleAssert.eventEmitted(approve, 'Approve', (ev) => {
            return ev._sender == buyer && ev._spender == exchanger.address && ev._value == tokensToSell;
        }, "Approve should trigger correct 'Approve' event.");
        expect((await token.allowance(buyer, exchanger.address)).toNumber()).to.eq(tokensToSell);

        // Sell
        const sell = await exchanger.sell(tokensToSell, {from: buyer});
        truffleAssert.eventEmitted(sell, 'Sell', (ev) => {
            return ev._seller == buyer && ev._value == tokensToSell;
        }, "Sell should trigger correct 'Sell' event.");
        expect((await token.balanceOf(buyer)).toNumber()).to.eq(tokensToBuy - tokensToSell);
        expect((await token.balanceOf(exchanger.address)).toNumber()).to.eq(tokensOnDeploy - tokensToBuy + tokensToSell);
    });

    it("should not allow to sell if not approved", async () => {
        await exchanger.sendTransaction({value: 2, from: buyer});
        await truffleAssert.reverts(
            exchanger.sell(2, {from: buyer}),
            "No allowance!"
        );
    });

    it("should not allow to sell or donate if not enough tokens", async () => {
        await exchanger.sendTransaction({value: 2, from: buyer});
        await truffleAssert.reverts(
            exchanger.sell(3, {from: buyer}),
            "Incorrect value for transaction!"
        );
        await truffleAssert.reverts(
            exchanger.donate(3, {from: buyer}),
            "Incorrect value for transaction!"
        );
    });
});
