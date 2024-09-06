I think such decomposition does generally exist. The decomposition could be done in the following steps:

1. Decompose the matrix M into the production of a series of elementary matrices. This could be done by doing some row operations to first transform M into an upper triangular matrix, then into a diagonal matrix. The row operators could be considered as multiplying a series of elementary matrices on the left of M, and the resulting diagonal matrix could also be considered as the production of a series of elementary matrices. Thus we have:

$$
    P_{m+1}^{-1}P_{m+2}^{-1} \cdots P_n M = P_{1} \cdots P_m \\
    M = P_{1} \cdots P_n
$$

  where $P_i$ are elementary matrics.

2. In the series of $P_i$, "exchange" the position of the row multiplication matrix with its left neighbor one by one, and finally make all row multiplication matrices at the left of the others. The "exchange" rules would make the multiplication result does not change. I will explain the rule in detail, let's say $A$ is a row multiplication matrix, $B$ is a row-switching matrix, $C$ is a row addition matrix:

     * if $A$ and $B$ operate on different rows, it could be exchanged directly: $AB = BA$. Same for $A$ and $C$.

     * if $B$ switched the row $A$ multiplied, let "switched $A$" multiply on another row operated by $B$. for example:

$$
\begin{pmatrix}
      0 & 1 & 0 \\
      1 & 0 & 0 \\
      0 & 0 & 1
    \end{pmatrix}
    \begin{pmatrix}
      r & 0 & 0 \\
      0 & 1 & 0 \\
      0 & 0 & 1
    \end{pmatrix} =
    \begin{pmatrix}
      1 & 0 & 0 \\
      0 & r & 0 \\
      0 & 0 & 1
    \end{pmatrix}
    \begin{pmatrix}
      0 & 1 & 0 \\
      1 & 0 & 0 \\
      0 & 0 & 1
\end{pmatrix}
$$

* if $C$ added the row operated by $A$ on another row, the "switched $C$" should be modified, for example:

$$
\begin{pmatrix}
      1 & 0 & 0 \\
      s & 1 & 0 \\
      0 & 0 & 1
    \end{pmatrix}
    \begin{pmatrix}
      r & 0 & 0 \\
      0 & 1 & 0 \\
      0 & 0 & 1
    \end{pmatrix} =
    \begin{pmatrix}
      r & 0 & 0 \\
      0 & 1 & 0 \\
      0 & 0 & 1
    \end{pmatrix}
    \begin{pmatrix}
      1 & 0 & 0 \\
      rs & 1 & 0 \\
      0 & 0 & 1
\end{pmatrix}
$$

* if $C$ added another row to the row operated by $A$，also do some modify on "switched $C$", for example:
  $$
  \begin{pmatrix}
        1 & s & 0 \\
        0 & 1 & 0 \\
        0 & 0 & 1
      \end{pmatrix}
      \begin{pmatrix}
        r & 0 & 0 \\
        0 & 1 & 0 \\
        0 & 0 & 1
      \end{pmatrix} =
      \begin{pmatrix}
        r & 0 & 0 \\
        0 & 1 & 0 \\
        0 & 0 & 1
      \end{pmatrix}
      \begin{pmatrix}
        1 & s/r & 0 \\
        0 & 1 & 0 \\
        0 & 0 & 1
  \end{pmatrix}
  $$
  Finally we would get:
  $$
  M = R_1R_2\cdots R_p S_1S_2\cdots S_q
  $$
  Where $R_i$ are row multiplication matrix, $S_i$ are row-switching matrix or row addition matrix.

3. It could be easily validated that $R_1R_2\cdots R_p$ gives a diagonal matrix, $S_1S_2\cdots S_q$ gives a orthogonal matrix.