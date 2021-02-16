import pytest


@pytest.fixture
def gov(accounts):
    yield accounts[0]


@pytest.fixture
def rewards(accounts):
    yield accounts[1]


@pytest.fixture
def guardian(accounts):
    yield accounts[2]


@pytest.fixture
def management(accounts):
    yield accounts[3]


@pytest.fixture
def create_token(gov, Token):
    def create_token():
        return Token.deploy({"from": gov})

    yield create_token


# NOTE: Only apply check for working with non-compliant tokens in tests
#       that work directly with the Vault
@pytest.fixture(params=["Normal", "NoReturn"])
def token(create_token, request):
    token = create_token()
    # NOTE: Run our test suite using both compliant and non-compliant ERC20 Token
    if request.param == "NoReturn":
        token._initialized = False  # otherwise Brownie throws an `AttributeError`
        setattr(token, "transfer", token.transferWithoutReturn)
        setattr(token, "transferFrom", token.transferFromWithoutReturn)
        setattr(token, "approve", token.approveWithoutReturn)
        token._initialized = True  # shhh, nothing to see here...
    yield token


@pytest.fixture
def create_vault(gov, guardian, rewards, create_token, patch_vault_version):
    def create_vault(token=None, version=None, governance=gov):
        if token is None:
            token = create_token()
        vault = patch_vault_version(version).deploy({"from": guardian})
        vault.initialize(token, governance, rewards, "", "", guardian)
        vault.setDepositLimit(2 ** 256 - 1, {"from": governance})
        return vault

    yield create_vault


@pytest.fixture
def vault(gov, management, token, create_vault):
    vault = create_vault(token=token, governance=gov)
    vault.setManagement(management, {"from": gov})
    # Make it so vault has some AUM to start
    token.approve(vault, token.balanceOf(gov) // 2, {"from": gov})
    vault.deposit(token.balanceOf(gov) // 2, {"from": gov})
    yield vault


@pytest.fixture
def strategist(accounts):
    yield accounts[4]


@pytest.fixture
def keeper(accounts):
    yield accounts[5]


@pytest.fixture
def proxyFactory(gov, ProxyFactoryInitializable):
    yield gov.deploy(ProxyFactoryInitializable)


@pytest.fixture(params=["NoProxy", "Proxy"])
def strategy(
    gov, strategist, keeper, rewards, token, vault, TestStrategy, proxyFactory, request
):
    strategy = strategist.deploy(TestStrategy, vault)

    if request.param == "Proxy":
        # prepare call and data to initialize the proxy
        data = strategy.initialize.encode_input(vault, strategist, rewards, keeper)
        # deploy the proxy using as logic the original strategy
        tx = proxyFactory.deployMinimal(strategy, data, {"from": strategist})
        # strategy proxy address is returned in the event ProxyCreated
        strategyAddress = tx.events["ProxyCreated"]["proxy"]
        # redefine strategy as the new proxy deployed
        strategy = TestStrategy.at(strategyAddress, owner=strategist)

    strategy.setKeeper(keeper, {"from": strategist})
    vault.addStrategy(
        strategy,
        4_000,  # 40% of Vault
        0,  # Minimum debt increase per harvest
        2 ** 256 - 1,  # maximum debt increase per harvest
        1000,  # 10% performance fee for Strategist
        {"from": gov},
    )
    yield strategy


@pytest.fixture
def rando(accounts):
    yield accounts[9]


@pytest.fixture(scope="session")
def registry_deployment_txn(web3):
    from collections import namedtuple

    # NOTE: Registry deployment txn of v2.registry.ychad.eth on mainnet
    txn = web3._mainnet.eth.getTransaction(
        "0x61db0649f50c4839010e6d4cdd0fac960f25b86c4f0328912fb96859b4827560"
    )
    # NOTE: Just did this so we pass around a smaller object
    yield namedtuple("Transaction", ["sender", "nonce"])(
        sender=txn["from"], nonce=txn["nonce"]
    )


@pytest.fixture
def registry(accounts, web3, registry_deployment_txn, gov, Registry):
    # Load account that deployed the registry on mainnet,
    # and set the nonce to just before that transaction
    registry_deployer = accounts.at(registry_deployment_txn.sender, force=True)
    # NOTE: This sucks, but there's no `set_nonce` yet
    while registry_deployer.nonce < registry_deployment_txn.nonce:
        registry_deployer.transfer(registry_deployer, 0)

    registry = Registry.deploy({"from": registry_deployer})
    assert registry.address == web3._mainnet.ens.address("v2.registry.ychad.eth")

    registry.setGovernance(gov, {"from": registry_deployer})
    registry.acceptGovernance({"from": gov})
    yield registry
