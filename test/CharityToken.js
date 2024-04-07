const truffleAssert = require('truffle-assertions');
const CharityToken = artifacts.require("CharityToken");

contract("CharityToken", (accounts) => {
    let token;
    let owner;
    let needies;
    const initTokensNum = 300;

    beforeEach(async function() {
        [owner] = accounts;
        needies = accounts.slice(1, 4);
        token = await CharityToken.new(owner);
    });

    it("should allow to register new needy", async () => {
        const needy = needies[0];
        await truffleAssert.reverts(
            token.registerDonateNeeds(0, {from: needy}),
            "Needs should be > 0!"
        );
        
        const needs = 5;
        const register = await token.registerDonateNeeds(needs, {from: needy});
        truffleAssert.eventEmitted(register, 'NeedsRegister', (ev) => {
            return ev._needy == needy && ev._needs == needs;
        }, "registerDonateNeeds should trigger correct 'NeedsRegister' event.");
        expect((await token.donateNeed(needy)).toNumber()).to.eq(needs);
        expect((await token.donateBalance(needy)).toNumber()).to.eq(0);
    });

    it("should allow to donate", async () => {        
        // Check donation when no needies
        await truffleAssert.reverts(
            token.donate(1),
            "No needies now!"
        );

        // Add needy
        const tokensNeeded = 3;
        const needy = needies[0];
        await token.registerDonateNeeds(tokensNeeded, {from: needy});

        // Donate to needy
        const tokensToDonate = 1;
        await token.donate(tokensToDonate);
        expect((await token.donateNeed(needy)).toNumber()).to.eq(tokensNeeded);
        expect((await token.donateBalance(needy)).toNumber()).to.eq(tokensToDonate);

        // Fulfill need
        const tokensToFulfill = tokensNeeded - tokensToDonate;
        const fulfillDonation = await token.donate(tokensToFulfill);
        truffleAssert.eventEmitted(fulfillDonation, 'NeedsAchieved', (ev) => {
            return ev._needy == needy;
        }, "Last donation should trigger correct 'NeedsAchieved' event.");
        expect((await token.donateNeed(needy)).toNumber()).to.eq(0);
        expect((await token.donateBalance(needy)).toNumber()).to.eq(0);
    });

    it("should allow to donate all at once", async () => {
        // Check donation when no needies
        await truffleAssert.reverts(
            token.donateAll(1),
            "No needies now!" 
        );

        // Add needies
        for (const needy of needies) {
            await token.registerDonateNeeds(1, {from: needy});
        }

        // Check donation when needies > donation sum
        await truffleAssert.reverts(
            token.donateAll(needies.length - 1),
            "Needies number is more than donation sum!" 
        );

        // Donate to all needies
        const tokensToDonate = 5;
        await token.donateAll(tokensToDonate);
        let needs = 0;
        let balances = 0;
        for (const needy of needies) {
            needs += (await token.donateNeed(needy)).toNumber();
            balances += (await token.donateBalance(needy)).toNumber();
        }
        expect(needs).to.eq(0);
        expect(balances).to.eq(0);
        expect((await token.balanceOf(owner)).toNumber()).to.eq(initTokensNum - needies.length);
    });
});