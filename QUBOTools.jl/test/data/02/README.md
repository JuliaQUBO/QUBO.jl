# Model 2 ~ Simple model with solutions

The problem is:
$$f(x_1, x_3, x_5) = 2.7 \left( 1.93 + 0.4 x_3 - 4.4 x_5 - 0.8 x_1 x_3 + 6 x_1 x_5 \right)$$
or
$$f(s_1, s_3, s_5) = 2.7 \left( 1.23 + 1.3 s_1 - 0.7 s_3 - 0.2 s_1 s_2 + 1.5 s_1 s_3 \right)$$

## Status Table
| Format   | Domain | Status |
| :------- | :----: | :----: |
| BQPJSON  |  Bool  |   ✔️    |
| BQPJSON  |  Spin  |   ✔️    |
| MiniZinc |  Bool  |   ❌    |
| MiniZinc |  Spin  |   ❌    |
| QUBO     |  Bool  |   ✔️    |
| Qubist   |  Spin  |   ✔️    |

[symbols]: # (✔️❌)