SortPerf.jl: Module to test the performance of sorting algorithms
--------------------------------------------------------------

The purpose of this module is to test the performance of the different sort (and related) algorithms in Julia.  


**`SortPerf.sortperf()`** is a set of identically named functions which allow the testing of different sorting algorithms on different data with various sizes and parameters.  Run with:

    sortperf(Algorithm(s), data)

to test an Algorithm or Algorithms (QuickSort, InsertionSort, MergeSort, or TimSort)on a particular data set.  

You can also specify one or more `DataTypes` (`Int`, `Float32`, `Float64`, or `String` only) and one or more sizes (multiple sizes are specified by their log2 values):

    sortperf(QuickSort, Int, 10_000)               # Test QuickSort on 10,000 random ints
    sortperf(MergeSort, [Float32, String], 6:2:10) # Test MergeSort on 2^6, 2^8, and 2^10 float 32s and strings
    sortperf([QuickSort, MergeSort, TimSort],      # Test QuickSort, MergeSort, and TimSort on 
             [Int, Float32, Float64, String],      # Arrays of Int, Float32, Float64, and String
             6:20;                                 # ranging from 2^6 elements to 2^20 elements, by 
             replicates=5)                         # powers of 2, and run each test 5 times

Ordering parameters accepted by sort!() (i.e., `rev=true` or `false`, `by=`, `lt=`, and `order=`) will be passed through.


**SortPerf.std_sort_tests()** will run tests all standard sorting algorithms on random arrays of `Ints`, `Float64s`, and `Strings`.

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
