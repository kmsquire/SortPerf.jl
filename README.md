SortPerf.jl: Module to test the performance of sorting algorithms
--------------------------------------------------------------

The purpose of this module is to test the performance of the different sort (and related) algorithms in Julia.  Run with:

    std_sort_tests(;sort_algs=SortPerf.sort_algs,   # [InsertionSort, HeapSort, MergeSort, 
                                                    #     QuickSort, RadixSort, TimSort]
                    types=SortPerf.std_types,       # [Int32, Int64, Int128, Float32, Float64, String]
                    range=6:20,                     # Array size 2^6 through 2^20, by powers of 2
                    replicates=3,                   #
                    lt::Function=isless,            # \
                    by::Function=identity,          #  | sort(...) options
                    rev::Bool=false,                #  |
                    order::Ordering=Forward,        # /
                    save::Bool=false,               # create and save timing tsv and pdf plot
                    prefix="sortperf")              # prefix for saved files

You can also test individual algorithms with 

    sortperf(Algorithm(s), data, [size,] [replicates=xxx])

Some examples:

    sortperf(QuickSort, Int, 10_000)               # Test QuickSort on 10,000 random ints
    sortperf(MergeSort, [Float32, String], 6:2:10) # Test MergeSort on 2^6, 2^8, and 2^10 float 32s and strings
    sortperf([QuickSort, MergeSort, TimSort],      # Test QuickSort, MergeSort, and TimSort on 
             [Int, Float32, Float64, String],      # Arrays of Int, Float32, Float64, and String
             6:20;                                 # ranging from 2^6 elements to 2^20 elements, by 
             replicates=5)                         # powers of 2, and run each test 5 times

Ordering parameters accepted by sort!(...) will be passed through.


Sorting Tests
-------------

The actual tests run include sorting arrays with the following characteristics:

* random
* sorted
* reversed
* sorted, but with 3 random exchanges
* sorted, with 10 random values appended
* 4 unique values
* all equal
* quicksort median killer: first half descending, second half ascending

The tests were inspired by similar tests used by sortperf in Python.  See http://svn.python.org/projects/python/trunk/Objects/listsort.txt for more details.



Suggestions based on basic tests
--------------------------------

Here is a table and some notes on the Julia implementations of the
various algorithms.  The table indicates the recommended sort
algorithm for the given size (`small < ~2^12 (=8,192) items < large`)
and type (string, floating point, or integer) of data.

- *Random* means that the data is permuted randomly.
- *Structured* here means that the data contains partially sorted runs
(such as when adding random data to an already sorted array).
- *Few unique* indicates that the data only contains a few unique
values.


|               |(Un)stable (small)|Stable (small)|(Un)stable (large)|Stable (large)|In-place (large)|
|---------------|:----------------:|:------------:|:----------------:|:------------:|:--------------:|
|**Strings**    |                  |              |                  |              |                |
|- Random       |M                 |M             |M                 |M             |Q               |
|- Structured   |M                 |M             |T                 |T             |Q               |
|- Few Unique   |Q                 |M             |Q                 |M             |Q               |
|               |                  |              |                  |              |                |
|**Float64**    |                  |              |                  |              |                |
|- Random       |Q                 |M             |R                 |R             |Q               |
|- Structured   |M                 |M             |T                 |T             |Q               |
|- Few Unique   |Q                 |M             |Q                 |R             |Q               |
|               |                  |              |                  |              |                |
|**Int64**      |                  |              |                  |              |                |
|- Random       |Q                 |M             |R                 |R             |Q               |
|- Structured   |Q                 |M             |uT                |R/T           |Q               |
|- Few Unique   |Q                 |M             |R                 |R             |Q               |

Key:

|Symbol|Algorithm        |
|------|-----------------|
|H     |`HeapSort`       |
|I     |`InsertionSort`  |
|M     |`MergeSort`      |
|Q     |`QuickSort`      |
|T     |`TimSort`        |
|uT    |`TimSortUnstable`|
|R     |`RadixSort`      |


Current Recommendations
-----------------------

* Except for pathological cases, small arrays are sorted best with
  `QuickSort` (unstable) or `MergeSort`` (stable)

* When sorting large arrays with sections of already-sorted data, use
  `TimSort`.  The only structured case it does not handle well is
  reverse-sorted data with large numbers of repeat elements.  An
  unstable version of `TimSort` (to be contributed to Julia soon) will
  handle this case

* For numerical data (Ints or Floats) without structure, `RadixSort` is
  the best choice, except for 1) 128-bit values, or 2) 64-bit integers
  which span the full range of values.

* When memory is tight, `QuickSort` is the best in-place algorithm.  If
  there is concern about pathological cases, use `HeapSort`.  All
  stable algorithms use additional memory, but `TimSort` is (probably)
  the most frugal.

* **Composite types may behave differently.**  If sorting is
  important to your application, you should test the different
  algorithms on your own data.  This package facilitates that.

