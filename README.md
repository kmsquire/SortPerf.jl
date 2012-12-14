SortPerf.jl: Module to test the performance of sorting algorithms
--------------------------------------------------------------

The purpose of this module is to test the performance of the
different sort (and related) algorithms in Julia.  

* `SortPerf.std_sort_tests()` will run tests on the standard sorting
algorithms.

* `SortPerf.perm_sort_tests()` will run tests on the sorting algorithms
which return a permutation

* `SortPerf.*_sort_tests(true[, pdffile])` will save timing plots to a pdf
file.

* `SortPerf.run_sort_tests(...)` and `SortPerf.sortperf(...)` allow finer
grained control over the tests that are run.

The tests were inspired by similar tests used by sortperf in Python.
See http://svn.python.org/projects/python/trunk/Objects/listsort.txt
for more details.
