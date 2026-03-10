#include <stdio.h>
#include <string.h>

#define N 6

typedef int matrix_t[N][N];
typedef int vector_t[N];

/*==--------------------------------------------------==*/
/* -------------------- Operations -------------------- */
/*==--------------------------------------------------==*/

void matrix_add(matrix_t a, matrix_t b, matrix_t out)
{
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++)
            out[i][j] = a[i][j] || b[i][j];
}

void matrix_inter(matrix_t a, matrix_t b, matrix_t out)
{
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++)
            out[i][j] = a[i][j] && b[i][j];
}

void matrix_mul(matrix_t a, matrix_t b, matrix_t out)
{
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            int val = 0;
            for (int k = 0; k < N; k++) {
                if (a[i][k] && b[k][j]) {
                    val = 1;
                    break;
                }
            }
            out[i][j] = val;
        }
    }
}

void matrix_sub(matrix_t a, matrix_t b, matrix_t out)
{
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++)
            out[i][j] = a[i][j] && !b[i][j];
}

void matrix_not(matrix_t a, matrix_t out)
{
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++)
            out[i][j] = !a[i][j];
}

void matrix_copy(matrix_t src, matrix_t dst)
{
    memcpy(dst, src, sizeof(matrix_t));
}

int matrix_eq(matrix_t a, matrix_t b)
{
    return memcmp(a, b, sizeof(matrix_t)) == 0;
}

void matrix_identity(matrix_t m)
{
    memset(m, 0, sizeof(matrix_t));
    for (int i = 0; i < N; i++)
        m[i][i] = 1;
}

void matrix_transpose(matrix_t a, matrix_t out)
{
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++)
            out[j][i] = a[i][j];
}

void matrix_show(matrix_t m)
{
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++)
            printf("%d ", m[i][j]);
        printf("\n");
    }
}

/*==--------------------------------------------------==*/
/* ---------- Extended transitive closure ------------- */
/*==--------------------------------------------------==*/
void transitive_closure_extended(matrix_t s, matrix_t a, matrix_t c, matrix_t out)
{
    matrix_t x, step, tmp;
    matrix_copy(s, x);
    while (1) {
        matrix_mul(a, x, tmp);
        matrix_inter(tmp, c, step);
        matrix_add(x, step, tmp);
        if (matrix_eq(x, tmp)) break;
        matrix_copy(tmp, x);
    }
    matrix_copy(x, out);
}

/*==--------------------------------------------------==*/
/* ------------------- SSA matrices ------------------- */
/*==--------------------------------------------------==*/
void dominance_relation(matrix_t A, matrix_t M)
{
    matrix_t I, M0, notM0, notI, tmp;
    matrix_identity(I);
    matrix_not(I, notI);

    // M0
    for (int r = 0; r < N; r++) {
        for (int c = 0; c < N; c++) {
            if (r == 0)
                M0[r][c] = (c == 0);
            else
                M0[r][c] = 1;
        }
    }
    matrix_not(M0, notM0);

    transitive_closure_extended(notM0, A, notI, tmp);
    matrix_not(tmp, M);
}

void dominance_frontier(matrix_t A, matrix_t M, matrix_t D)
{
    matrix_t AM, sub;
    matrix_mul(A, M, AM);
    matrix_sub(AM, M, sub);
    matrix_transpose(sub, D);
}

void transitive_closure(matrix_t m)
{
    for (int k = 0; k < N; k++)
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++)
                if (m[i][k] && m[k][j]) m[i][j] = 1;
}

void vector_mul(vector_t v, matrix_t m, vector_t out)
{
    for (int j = 0; j < N; j++) {
        int val = 0;
        for (int i = 0; i < N; i++) {
            if (v[i] && m[i][j]) {
                val = 1;
                break;
            }
        }
        out[j] = val;
    }
}

void vector_show(vector_t v)
{
    for (int i = 0; i < N; i++)
        printf("%d ", v[i]);
    printf("\n");
}

/*==--------------------------------------------------==*/
/* --------------------- Driver ----------------------- */
/*==--------------------------------------------------==*/
int main()
{
    matrix_t A = {
        {0,0,0,0,0,0},
        {1,0,0,0,1,0},
        {0,1,0,0,0,0},
        {0,1,0,0,0,0},
        {0,0,1,1,0,0},
        {1,0,0,0,1,0}
    };

    matrix_t M, D, J;
    dominance_relation(A, M);
    dominance_frontier(A, M, D);
    matrix_copy(D, J);
    transitive_closure(J);

    printf("M matrix:\n");
    matrix_show(M);
    printf("\nD matrix:\n");
    matrix_show(D);
    printf("\nJ+ matrix:\n");
    matrix_show(J);

    // φ-placement example
    vector_t defs = {1,0,1,0,0,0};
    vector_t result;
    vector_mul(defs, J, result);
    printf("\nPhi placement vector:\n");
    vector_show(result);

    return 0;
}
