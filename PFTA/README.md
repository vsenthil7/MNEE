# PFTA â€” Programmable Finance & Treasury Automation (Product-3)

This repo is a Hardhat (JS) project implementing:
- TreasuryVault (custody + scheduler authorization)
- PolicyEngine (payment rules)
- PaymentScheduler (time/condition execution)
- MockToken (ERC20 test asset)

## Prerequisites
- Node 18.x
- npm
- Git

## Install
Dependencies already installed in this workspace. If rebuilding:
1) 
pm install

## Compile
- 
pm run compile

## Test (Definition of Done)
- 
pm test

## Local Manual Run
1) Deploy:
- 
pm run deploy:local

2) Seed treasury:
- 
pm run seed:local

3) Run payment demo:
- 
pm run run:payment

## Security / Secrets
- Do NOT commit .env
- Only .env.example is committed