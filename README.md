# Compile
aptos move compile --named-addresses movegpt=0xcafe,deployer=0xcafe1
# Running tests
aptos move test --named-addresses movegpt=0xcafe,deployer=0xcafe
# Deploy
aptos move create-resource-account-and-publish-package --profile test2 --named-addresses deployer=test2 --seed 1 --address-name movegpt --included-artifacts none

aptos move publish --named-addresses movegpt=test7,deployer=test7 --profile test7 --included-artifacts none
