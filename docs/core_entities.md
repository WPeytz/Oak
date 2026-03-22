## Core entities

### User
- id
- email
- created_at

### BankConnection
- id
- user_id
- provider ("tink")
- institution_id
- requisition_id
- status
- created_at
- last_synced_at

### BankAccount
- id
- user_id
- connection_id
- provider_account_id
- name
- iban_masked
- currency

### Transaction
- id
- user_id
- bank_account_id
- provider_transaction_id
- booked_at
- value_date
- amount
- currency
- merchant
- raw_description
- raw_category
- normalized_category
- is_essential
- source

### SpendingGoal
- id
- user_id
- monthly_discretionary_budget
- monthly_savings_target

### TreeState
- id
- user_id
- date
- health_score
- leaf_density
- stress_level
- dominant_spending_category
- explanation