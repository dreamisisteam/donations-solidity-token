const truffleAssert = require('truffle-assertions');
const DonationExchanger = artifacts.require("DonationExchanger");
const DonationToken = artifacts.require("DonationToken");

contract("DonationToken", (accounts) => {
    let token;
    let owner;
    let needies;
    const initTokensNum = 300;
    const GweiToWei = 10**9;

    beforeEach(async function() {
        exchanger = await DonationExchanger.new();
        token = await DonationToken.at(await exchanger.token());
        await exchanger.sendTransaction({value: 300*GweiToWei});
        [owner] = accounts;
        needies = accounts.slice(1, 4);
    });

    it("should allow to register new member", async () => {
        const newMember = needies[0];

        await truffleAssert.reverts(
            token.registerMember(newMember, {from: newMember}),
            "This operation is allowed only to moderator!"
        );
        const register = await token.registerMember(newMember);
        truffleAssert.eventEmitted(register, 'MemberRegister', (ev) => {
            return ev._member == newMember;
        }, "registerMember should trigger correct 'MemberRegister' event.");
        expect((await token.membersRegistry(0))).to.eq(newMember);
        await truffleAssert.reverts(
            token.registerMember(newMember),
            "This needy is already a member!"
        );
    });

    it("should allow to disable member", async () => {
        const newMember = needies[0];
        await truffleAssert.reverts(
            token.disableMember(newMember, {from: newMember}),
            "This operation is allowed only to moderator!"
        );
        await truffleAssert.reverts(
            token.disableMember(newMember),
            "This needy is not a member!"
        );

        await token.registerMember(newMember);
        const disable = await token.disableMember(newMember);
        truffleAssert.eventEmitted(disable, 'MemberDisabled', (ev) => {
            return ev._member == newMember;
        }, "disableMember should trigger correct 'MemberDisabled' event.");
        
        // Check if still member
        await truffleAssert.reverts(
            token.disableMember(newMember),
            "This needy is not a member!"
        );
    });

    it("should allow to register new need", async () => {
        const member = needies[0];
        const needName = "napokushat";
        
        await truffleAssert.reverts(
            token.registerDonateNeeds(needName, 0, {from: member}),
            "This operation is allowed only for member!"
        );

        await token.registerMember(member);
        await truffleAssert.reverts(
            token.registerDonateNeeds(needName, 0, {from: member}),
            "Needs should be > 0!"
        );
        await truffleAssert.reverts(
            token.registerDonateNeeds("", 5, {from: member}),
            "Need name should not be blank!"
        );
        
        const needs = 5;
        const register = await token.registerDonateNeeds(needName, needs, {from: member});
        truffleAssert.eventEmitted(register, 'NeedsRegister', (ev) => {
            return ev._member == member && ev._needName == needName;
        }, "registerDonateNeeds should trigger correct 'NeedsRegister' event.");
        expect((await token.donateNeedsNames(member))).to.have.all.members([needName]);
        expect((await token.donateNeed(member, needName)).toNumber()).to.eq(needs);
        expect((await token.donateBalance(member)).toNumber()).to.eq(0);
    });

    it("should allow to remove created need", async () => {
        const member = needies[0];
        const needName = "napokushat";
        
        await truffleAssert.reverts(
            token.deleteDonateNeeds("", {from: member}),
            "This operation is allowed only for member!"
        );
        await token.registerMember(member);
        await truffleAssert.reverts(
            token.deleteDonateNeeds("", {from: member}),
            "Should be existing donate need!"
        );
        
        const needs = 5;
        await token.registerDonateNeeds(needName, needs, {from: member});
        const remove = await token.deleteDonateNeeds(needName, {from: member});
        truffleAssert.eventEmitted(remove, 'NeedsDeletion', (ev) => {
            return ev._member == member && ev._needName == needName;
        }, "deleteDonateNeeds should trigger correct 'NeedsDeletion' event.");
        expect((await token.donateNeedsNames(member)).length).to.eq(0);
        expect((await token.donateNeed(member, needName)).toNumber()).to.eq(0);
    });

    it("should allow to donate specific member", async () => {
        // Check donation when no needies
        await truffleAssert.reverts(
            token.donateTransfer(needies[0], 1),
            "Recipient is not a member!"
        );

        // Add needy
        const tokensNeeded = 3;
        const needy = needies[0];
        const needName = "napokushat";
        await token.registerMember(needy);
        await token.registerDonateNeeds(needName, tokensNeeded, {from: needy});

        // Donate to needy
        const tokensToDonate = 1;
        await token.donateTransfer(needy, tokensToDonate);
        expect((await token.donateNeed(needy, needName)).toNumber()).to.eq(tokensNeeded);
        expect((await token.donateBalance(needy)).toNumber()).to.eq(tokensToDonate);
    });

    it("should allow to donate random", async () => {
        // Check donation when no needies
        await truffleAssert.reverts(
            token.donate(1, {from: owner}),
            "No members yet!"
        );

        // Add needy
        const tokensNeeded = 3;
        const needy = needies[0];
        const needName = "napokushat";
        await token.registerMember(needy);
        await token.registerDonateNeeds(needName, tokensNeeded, {from: needy});

        // Donate to needy
        const tokensToDonate = 1;
        await token.donate(tokensToDonate);
        expect((await token.donateNeed(needy, needName)).toNumber()).to.eq(tokensNeeded);
        expect((await token.donateBalance(needy)).toNumber()).to.eq(tokensToDonate);
    });

    it("should allow to donate all at once", async () => {
        // Check donation when no needies
        await truffleAssert.reverts(
            token.donateAll(1, {from: owner}),
            "No members yet!" 
        );

        const needName = "napokushat";
        // Add needies
        for (const needy of needies) {
            await token.registerMember(needy);
            await token.registerDonateNeeds(needName, 1, {from: needy});
        }

        // Check donation when needies > donation sum
        await truffleAssert.reverts(
            token.donateAll(needies.length - 1),
            "Members number is more than donation sum!" 
        );

        // Donate to all needies
        const tokensToDonate = 5;
        await token.donateAll(tokensToDonate);
        let needs = 0;
        let balances = 0;
        for (const needy of needies) {
            needs += (await token.donateNeed(needy, needName)).toNumber();
            balances += (await token.donateBalance(needy)).toNumber();
        }
        const tokensDonated = Math.floor(tokensToDonate / needies.length) * needies.length;
        expect(needs).to.eq(tokensDonated);
        expect(balances).to.eq(tokensDonated);
        expect((await token.balanceOf(owner)).toNumber()).to.eq(initTokensNum - needies.length);
    });
});