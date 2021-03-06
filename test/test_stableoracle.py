import pytest
from rich.console import Console
import json

console = Console()


@pytest.fixture()
def tokens():
    with open('harvest_tokens.json') as json_file:
        data = json.load(json_file)

    l = []
    for i in data['data']:
        l.append(i['contract']['address'])

    yield l


@pytest.fixture()
def storage(Storage, accounts):
    accounts.default = accounts[0]
    yield Storage.deploy()


@pytest.fixture()
def registry(Contract):
    r = []
    token = '0x4bd17003473389a42daf6a0a729f6fdb328bbbd7'
    target = '0x191409D5A4EfFe25b0f4240557BA2192D18a191e'
    c = Contract.from_explorer('0x191409D5A4EfFe25b0f4240557BA2192D18a191e')
    data = c.get_dy_underlying.encode_input(0, 1, 10 ** 18)
    r.append([token, target, data])

    token = '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d'
    target = '0x160CAed03795365F3A589f10C379FfA7d75d4E76'
    c = Contract.from_explorer('0x191409D5A4EfFe25b0f4240557BA2192D18a191e')
    data = c.get_dy_underlying.encode_input(0, 1, 10 ** 18)
    r.append([token, target, data])

    token = '0x049d68029688eabf473097a2fc38ef61633a3c7a'
    target = '0x556ea0b4c06D043806859c9490072FaadC104b63'
    c = Contract.from_explorer('0x556ea0b4c06D043806859c9490072FaadC104b63')
    data = c.get_dy_underlying.encode_input(0, 1, 10 ** 6)
    r.append([token, target, data])

    token = '0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3'
    target = '0xc6a752948627bECaB5474a10821Df73fF4771a49'
    c = Contract.from_explorer('0xc6a752948627bECaB5474a10821Df73fF4771a49')
    data = c.get_dy_underlying.encode_input(0, 1, 10 ** 18)
    r.append([token, target, data])

    token = '0x55d398326f99059ff775485246999027b3197955'
    target = '0x160CAed03795365F3A589f10C379FfA7d75d4E76'
    c = Contract.from_explorer('0x160CAed03795365F3A589f10C379FfA7d75d4E76')
    data = c.get_dy_underlying.encode_input(0, 2, 10 ** 18)
    r.append([token, target, data])

    token = '0xaF4dE8E872131AE328Ce21D909C74705d3Aaf452'
    target = '0x160CAed03795365F3A589f10C379FfA7d75d4E76'
    c = Contract.from_explorer('0x160CAed03795365F3A589f10C379FfA7d75d4E76')
    data = c.calc_withdraw_one_coin.encode_input(10 ** 18, 0)
    r.append([token, target, data])

    token = '0x373410a99b64b089dfe16f1088526d399252dace'
    target = '0x556ea0b4c06D043806859c9490072FaadC104b63'
    c = Contract.from_explorer('0x556ea0b4c06D043806859c9490072FaadC104b63')
    data = c.calc_withdraw_one_coin.encode_input(10 ** 18, 1)
    r.append([token, target, data])

    yield r


@pytest.fixture()
def o(OracleBSC, storage, accounts, registry):
    accounts.default = accounts[0]
    o = OracleBSC.deploy(storage.address)
    for r in registry:
        o.modifyRegistry(r[0], r[1], r[2])
        o.addStableToken(r[0])

    # btcb/renbtc -> btcb
    o.modifyReplacementTokens('0x2a435Ecb3fcC0E316492Dc1cdd62d0F189be5640',
                              '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c')

    yield o


def test(o, tokens, interface):
    for t in tokens:
        i = interface.BEP20(t)
        s = i.symbol()
        price = o.getPrice(t)
        assert o.getPrice(t) > 0
        console.print(f'{price / 1e18:.6f} {s}/BUSD')
