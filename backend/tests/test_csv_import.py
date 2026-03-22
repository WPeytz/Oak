from app.services.csv_import import parse_danske_bank_csv


SAMPLE_CSV = '''"Dato";"Kategori";"Underkategori";"Tekst";"Beløb";"Saldo";"Status";"Afstemt"
"22.02.2026";"Ukategoriseret";"Ukategoriseret";"MobilePay Rejsekort";"-57,20";"29.134,23";"Udført";"Nej"
"23.02.2026";"Dagligvarer";"Supermarked";"Netto Eremitage";"-96,95";"28.770,57";"Udført";"Nej"
"27.02.2026";"Ukategoriseret";"Ukategoriseret";"SU";"12.987,00";"41.257,29";"Udført";"Nej"
"23.02.2026";"Fornøjelser og fritid";"Café/restaurant";"Old Irish Pub V";"-50,00";"28.680,24";"Udført";"Nej"
"22.03.2026";"";"  ";"Claude.Ai Subscription";"-840,71";"";"Venter";"Nej"
'''


def test_parse_row_count():
    txns = parse_danske_bank_csv(SAMPLE_CSV)
    assert len(txns) == 5


def test_parse_amounts():
    txns = parse_danske_bank_csv(SAMPLE_CSV)
    amounts = {t["merchant"]: float(t["amount"]) for t in txns}
    assert amounts["MobilePay Rejsekort"] == -57.20
    assert amounts["Netto Eremitage"] == -96.95
    assert amounts["SU"] == 12987.00


def test_parse_dates():
    txns = parse_danske_bank_csv(SAMPLE_CSV)
    dates = {t["merchant"]: str(t["booked_at"]) for t in txns}
    assert dates["Netto Eremitage"] == "2026-02-23"
    assert dates["SU"] == "2026-02-27"


def test_categorization():
    txns = parse_danske_bank_csv(SAMPLE_CSV)
    cats = {t["merchant"]: t["normalized_category"] for t in txns}
    assert cats["Netto Eremitage"] == "groceries"
    assert cats["SU"] == "income"


def test_income_not_essential():
    txns = parse_danske_bank_csv(SAMPLE_CSV)
    su = next(t for t in txns if t["merchant"] == "SU")
    assert su["is_essential"] is False


def test_source_is_csv():
    txns = parse_danske_bank_csv(SAMPLE_CSV)
    assert all(t["source"] == "csv" for t in txns)


def test_stable_transaction_ids():
    txns1 = parse_danske_bank_csv(SAMPLE_CSV)
    txns2 = parse_danske_bank_csv(SAMPLE_CSV)
    ids1 = [t["provider_transaction_id"] for t in txns1]
    ids2 = [t["provider_transaction_id"] for t in txns2]
    assert ids1 == ids2  # same CSV produces same IDs


def test_empty_csv():
    txns = parse_danske_bank_csv("")
    assert txns == []


def test_header_only():
    txns = parse_danske_bank_csv('"Dato";"Kategori";"Tekst";"Beløb";"Saldo";"Status";"Afstemt"\n')
    assert txns == []
