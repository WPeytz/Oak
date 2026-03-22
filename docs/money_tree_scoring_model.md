## Money Tree scoring model (MVP)

Goal: convert recent financial behavior into a tree health score.

### Inputs
- discretionary spending this month
- spending relative to discretionary budget
- savings progress relative to goal
- concentration of spending in risky categories
- recent trend (improving / worsening)

### Outputs
- health_score: 0-100
- tree_state:
  - thriving
  - healthy
  - stressed
  - decaying
- explanation:
  plain-language reason for score

### Example rules
- staying below discretionary budget improves score
- exceeding budget reduces score
- repeated overspending in leisure/eating out/shopping increases stress
- progress toward savings target improves score
- extreme one-off non-essential purchases cause noticeable leaf loss

### Visual mapping
- 80-100 -> lush tree
- 60-79 -> healthy but slightly thin
- 40-59 -> visible leaf loss
- 20-39 -> sparse tree
- 0-19 -> decaying tree