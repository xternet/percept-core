### 1. Test
```
forge test --match-contract PerceptProviderTest -vvv
```
### 2. Create circuit & generate proof with its verifier contract:
1. In <b>./circuits</b>, create directory {name}
2. In dir. {name} create <b>{name}.circom</b>
3. In dir. {name} create <b>input.js</b>
4. (from percept-core) run:
```
sh ./circuits/generate.sh {name}
```
More data about the process inside <b>generate.sh</b> and in [circom docs](https://docs.circom.io/getting-started/installation/).
