const truffleAssert = require('truffle-assertions');
const DonationExchanger = artifacts.require("DonationExchanger");
const DonationToken = artifacts.require("DonationToken");

contract("DonationExchanger", (accounts) => {
    const tokensOnDeploy = 300;
    const GweiToWei = 10**9;
    let exchanger;
    let token;
    let owner;
    let buyer;

    beforeEach(async function() {
        [owner, buyer] = accounts;
        exchanger = await DonationExchanger.new();
        token = await DonationToken.at(await exchanger.token());
    });
    
    it("should have valid storage", async () => {
        expect(await exchanger.owner()).to.eq(owner);
        expect(await exchanger.token()).to.not.eq("0x0000000000000000000000000000000000000000");
    });

    it("should allow to buy and sell tokens", async () => {
        // Buy
        await truffleAssert.reverts(
            exchanger.sendTransaction({value: 1, from: buyer}),
            "Value is less than 1 gwei!"
        );
        await truffleAssert.reverts(
            exchanger.sendTransaction({value: 1.5*GweiToWei, from: buyer}),
            "Value should be integer gwei!"
        );
        const tokensToBuy = 3;
        const tx = await exchanger.sendTransaction({value: tokensToBuy * GweiToWei, from: buyer});
        truffleAssert.eventEmitted(tx, 'Buy', (ev) => {
            return ev._buyer == buyer && ev._value == tokensToBuy;
        }, "receive should trigger correct 'Buy' event.");
        expect((await token.balanceOf(buyer)).toNumber()).to.eq(tokensToBuy);
        expect((await token.balanceOf(exchanger.address)).toNumber()).to.eq(tokensOnDeploy - tokensToBuy);

        // Approve
        const tokensToSell = 2;
        await token.approve(exchanger.address, tokensToSell, {from: buyer});

        // Sell
        const sell = await exchanger.sell(tokensToSell, {from: buyer});
        truffleAssert.eventEmitted(sell, 'Sell', (ev) => {
            return ev._seller == buyer && ev._value == tokensToSell;
        }, "sell should trigger correct 'Sell' event.");
        expect((await token.balanceOf(buyer)).toNumber()).to.eq(tokensToBuy - tokensToSell);
        expect((await token.balanceOf(exchanger.address)).toNumber()).to.eq(tokensOnDeploy - tokensToBuy + tokensToSell);
    });

    it("should not allow to sell if not approved", async () => {
        await exchanger.sendTransaction({value: 2 * GweiToWei, from: buyer});
        await truffleAssert.reverts(
            exchanger.sell(2, {from: buyer}),
            "No allowance!"
        );
    });

    it("should not allow to sell if not enough tokens", async () => {
        await exchanger.sendTransaction({value: 2 * GweiToWei, from: buyer});
        await truffleAssert.reverts(
            exchanger.sell(3, {from: buyer}),
            "Not enough tokens!"
        );
    });

    it("should allow to buy more tokens than it has by the moment", async () => {
        const tokensToBuy = 20000;
        const tx = await exchanger.sendTransaction({value: tokensToBuy * GweiToWei, from: buyer});
        truffleAssert.eventEmitted(tx, 'Buy', (ev) => {
            return ev._buyer == buyer && ev._value == tokensToBuy;
        }, "receive should trigger correct 'Buy' event.");
    });
});
