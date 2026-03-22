import pytest
from app.providers.gocardless.sandbox import SandboxBankingProvider


@pytest.fixture
def provider():
    return SandboxBankingProvider()


@pytest.mark.asyncio
async def test_obtain_token(provider):
    token = await provider.obtain_token()
    assert token.access == "sandbox-access-token"
    assert token.refresh == "sandbox-refresh-token"


@pytest.mark.asyncio
async def test_list_institutions(provider):
    institutions = await provider.list_institutions("DK")
    assert len(institutions) >= 1
    assert all("DK" in i.countries for i in institutions)


@pytest.mark.asyncio
async def test_list_institutions_empty_country(provider):
    institutions = await provider.list_institutions("XX")
    assert institutions == []


@pytest.mark.asyncio
async def test_get_institution(provider):
    inst = await provider.get_institution("SANDBOXFINANCE_SFIN0000")
    assert inst.name == "Sandbox Finance"


@pytest.mark.asyncio
async def test_get_institution_unknown(provider):
    with pytest.raises(ValueError):
        await provider.get_institution("UNKNOWN_BANK")


@pytest.mark.asyncio
async def test_create_requisition(provider):
    req = await provider.create_requisition(
        redirect_url="https://example.com/callback",
        institution_id="SANDBOXFINANCE_SFIN0000",
    )
    assert req.status == "LN"
    assert len(req.accounts) == 1


@pytest.mark.asyncio
async def test_get_requisition(provider):
    created = await provider.create_requisition(
        redirect_url="https://example.com/callback",
        institution_id="SANDBOXFINANCE_SFIN0000",
    )
    fetched = await provider.get_requisition(created.id)
    assert fetched.id == created.id
    assert fetched.status == "LN"


@pytest.mark.asyncio
async def test_get_account_details(provider):
    account = await provider.get_account_details("sandbox-account-001")
    assert account.currency == "DKK"
    assert account.name == "Sandbox Checking"


@pytest.mark.asyncio
async def test_list_transactions(provider):
    txns = await provider.list_transactions("sandbox-account-001")
    assert len(txns) > 0
    assert all(t.currency == "DKK" for t in txns)
    assert any(float(t.amount) > 0 for t in txns)  # at least one income
    assert any(float(t.amount) < 0 for t in txns)  # at least one expense
