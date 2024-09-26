# Data Model

| Fields            |           Type           | Description | Required |
| :---------------- | :----------------------: | ----------- | :------: |
| `linear_terms`    |      `Dict{Int, T}`      |             |   YES    |
| `quadratic_terms` | `Dict{Tuple{Int,Int} T}` |             |   YES    |
| `offset`          |           `T`            |             |    NO    |
| `scale`           |           `T`            |             |    NO    |
| `id`              |          `Int`           |             |    NO    |