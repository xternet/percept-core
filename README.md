### 1. Testing
```
forge test --match-contract PerceptProviderTest -vvv
```
### 2. Create circuit & generate proof and its verifier contract:
1. In <b>./circuits</b>, create directory {name}
2. In dir. {name} create <b>{name}.circom</b>
3. In dir. {name} create <b>input.js</b>
4. (from percept-core) Run:
```
sh ./circuits/generate.sh {name}
```
More data about the process inside generate.sh as well as in [circom docs](https://docs.circom.io/getting-started/installation/)