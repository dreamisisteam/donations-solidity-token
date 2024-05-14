const truffleAssert = require('truffle-assertions');
const DonationToken = artifacts.require("DonationToken");

contract("DonationToken", (accounts) => {
    let token;
    let owner;
    let needies;
    const initTokensNum = 300;

    beforeEach(async function() {
        [owner] = accounts;
        needies = accounts.slice(1, 4);
        token = await DonationToken.new(owner);
    });

    it("should allow to register new member", async () => {
        const needy = needies[0];

        await truffleAssert.reverts(
            token.registerMember(needy, {from: needy}),
            "This operation is allowed only for owner!"
        );
        await token.registerMember(needy);
        await truffleAssert.reverts(
            token.registerMember(needy),
            "This needy is already a member!"
        );
    });

    it("should allow to disable member", async () => {
        const needy = needies[0];
        await truffleAssert.reverts(
            token.disableMember(needy, {from: needy}),
            "This operation is allowed only for owner!"
        );
        await truffleAssert.reverts(
            token.disableMember(needy),
            "This needy is not a member!"
        );

        await token.registerMember(needy);
        const disable = await token.disableMember(needy);
        truffleAssert.eventEmitted(disable, 'MemberDisabled', (ev) => {
            return ev._needy == needy;
        }, "disableMember should trigger correct 'MemberDisabled' event.");
        
        // Check if still member
        await truffleAssert.reverts(
            token.disableMember(needy),
            "This needy is not a member!"
        );
    });

    it("should allow to register new need", async () => {
        const needy = needies[0];
        const needName = "napokushat";
        
        await truffleAssert.reverts(
            token.registerDonateNeeds(needName, 0, {from: needy}),
            "This operation is allowed only for member!"
        );

        await token.registerMember(needy);
        await truffleAssert.reverts(
            token.registerDonateNeeds(needName, 0, {from: needy}),
            "Needs should be > 0!"
        );
        
        const needs = 5;
        const register = await token.registerDonateNeeds(needName, needs, {from: needy});
        truffleAssert.eventEmitted(register, 'NeedsRegister', (ev) => {
            return ev._needy == needy && ev._needs == needs;
        }, "registerDonateNeeds should trigger correct 'NeedsRegister' event.");
        expect((await token.donateNeed(needy, needName)).toNumber()).to.eq(needs);
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
        await token.registerMember(needy);
        await token.registerDonateNeeds("", tokensNeeded, {from: needy});

        // Donate to needy
        const tokensToDonate = 1;
        await token.donate(tokensToDonate);
        expect((await token.donateNeed(needy, "")).toNumber()).to.eq(tokensNeeded);
        expect((await token.donateBalance(needy)).toNumber()).to.eq(tokensToDonate);
    });

    it("should allow to donate all at once", async () => {
        // Check donation when no needies
        await truffleAssert.reverts(
            token.donateAll(1),
            "No needies now!" 
        );

        // Add needies
        for (const needy of needies) {
            await token.registerMember(needy);
            await token.registerDonateNeeds("", 1, {from: needy});
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
            needs += (await token.donateNeed(needy, "")).toNumber();
            balances += (await token.donateBalance(needy)).toNumber();
        }
        const tokensDonated = Math.floor(tokensToDonate / needies.length) * needies.length;
        expect(needs).to.eq(tokensDonated);
        expect(balances).to.eq(tokensDonated);
        expect((await token.balanceOf(owner)).toNumber()).to.eq(initTokensNum - needies.length);
    });
});