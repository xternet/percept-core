!/bin/sh
set -e

# !note before execution:
# 1. in ./circuits, create directory {name}
# 2. in {name} dir create: {name}.circom
# 3. in {name} dir create: {name}_input.json

# then (from percept-core) run: sh ./circuits/generate.sh {name}

CONTRACT=$1


PATH_DIR="./circuits/$CONTRACT"
PATH_COMPILE=${PATH_DIR}/0_compile
PATH_WITNESS_DIR=${PATH_DIR}/1_witness
PATH_CEREMONY=${PATH_DIR}/2_ceremony
PATH_KEYS=${PATH_DIR}/3_keys
PATH_PROOF=${PATH_DIR}/4_proof
PATH_CONTRACTS=${PATH_DIR}/5_contracts


rm -rf $PATH_COMPILE && mkdir $PATH_COMPILE
rm -rf $PATH_WITNESS_DIR && mkdir $PATH_WITNESS_DIR
rm -rf $PATH_CEREMONY && mkdir $PATH_CEREMONY
rm -rf $PATH_KEYS && mkdir $PATH_KEYS
rm -rf $PATH_PROOF && mkdir $PATH_PROOF
rm -rf $PATH_CONTRACTS && mkdir $PATH_CONTRACTS


# circuits/CONTRACT
PATH_INPUT=$PATH_DIR/${CONTRACT}_input.json
PATH_CIRCOM=$PATH_DIR/${CONTRACT}.circom

# 0_compile
PATH_COMPILE_JS=${PATH_COMPILE}/${CONTRACT}_js
PATH_WASM=${PATH_COMPILE_JS}/${CONTRACT}.wasm
PATH_GENERATE_WITNESS=${PATH_COMPILE_JS}/generate_witness.js
PATH_R1CS=${PATH_COMPILE}/${CONTRACT}.r1cs

# 1_wintess
PATH_WITNESS=${PATH_WITNESS_DIR}/witness.wtns

# 2_ceremony
PATH_PTAU0=${PATH_CEREMONY}/pot12_0000.ptau
PATH_PTAU1=${PATH_CEREMONY}/pot12_0001.ptau
PATH_PTAU_FINAL=${PATH_CEREMONY}/pot12_final.ptau

# 3_keys
PATH_ZKEY0=${PATH_KEYS}/${CONTRACT}_0000.zkey
PATH_ZKEY1=${PATH_KEYS}/${CONTRACT}_0001.zkey
PATH_VERIFICATION_KEY=${PATH_KEYS}/verification_key.json

# 4_proof
PATH_PROOF_JSON=${PATH_PROOF}/proof.json
PATH_PUBLIC_JSON=${PATH_PROOF}/public.json

# 5_contracts
PATH_VERIFIER_CONTRACT=${PATH_CONTRACTS}/${CONTRACT}_verifier.sol


  #compile circuts, result: generate_witness.js, contract.wasm, witness_calculator.js, contract.r1cs (circuit binaries)
  circom $PATH_CIRCOM --r1cs --wasm -o $PATH_COMPILE

  # generate witness.wtns (contains all computed signals)
  node $PATH_GENERATE_WITNESS $PATH_WASM $PATH_INPUT $PATH_WITNESS

  # Start 1st phase of the ceremony (circuit-independent)
  snarkjs powersoftau new bn128 12 $PATH_PTAU0

  # Contribute to the ceremony in 1st phase
  snarkjs powersoftau contribute $PATH_PTAU0 $PATH_PTAU1 --name="First contribution" -e="$(openssl rand -base64 20)"

  # Start 2nd phase of the ceremony (circuit-specific)
  snarkjs powersoftau prepare phase2 $PATH_PTAU1 $PATH_PTAU_FINAL -v

  # Generate .zkey (contains proving & verification keys with contribution)
  snarkjs groth16 setup $PATH_R1CS $PATH_PTAU_FINAL $PATH_ZKEY0

  # Contribute to the ceremony in 2nd phase (and generate 2nd .zkey)
  snarkjs zkey contribute $PATH_ZKEY0 $PATH_ZKEY1 --name="Second contribution" -e="$(openssl rand -base64 20)"

  # Export verification key into .json
  snarkjs zkey export verificationkey $PATH_ZKEY1 $PATH_VERIFICATION_KEY

  # Generate proof.json & public.json (input & outputs) using Groth16.
  snarkjs groth16 prove $PATH_ZKEY1 $PATH_WITNESS $PATH_PROOF_JSON $PATH_PUBLIC_JSON

  # Verify proof & public.json
  snarkjs groth16 verify $PATH_VERIFICATION_KEY $PATH_PUBLIC_JSON $PATH_PROOF_JSON

  # Generate verifier.sol
  snarkjs zkey export solidityverifier $PATH_ZKEY1 $PATH_VERIFIER_CONTRACT

  # Update verifier.sol solidity ver. from ^0.6.11 to ^0.8.0
  sed -i -e 's/pragma solidity \^0.6.11/pragma solidity \^0.8.0/g' $PATH_VERIFIER_CONTRACT


printf "\nParams to call verifyProof:\n"
cd $PATH_PROOF && snarkjs generatecall