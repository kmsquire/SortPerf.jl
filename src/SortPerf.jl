## modeled after sort tests in python's sortperf.py
##
## Kevin Squire
##

require("DataFrames")
require("Winston/src/Plot")
require("Winston")

module SortPerf

using Base
using DataFrames
using Plot
using Winston

randstr_fn(str_len::Int) = n -> [randstring(str_len) for i = 1:n]
randint_fn(m::Int) = n -> randi(m,n)


# Test sort performance on datasets with varying amounts of structure
function sortperf(tsort!::Function, n::Int, qsort_med_killer::Bool, randfn::Function)

    gc()
    srand(1)
    times = Dict{String, Float64}()
    data = randfn(n)

    ## Random
    gc()
    times["*sort"] = @elapsed tsort!(data)
    ## TODO: allow issorted to be passed in, so we can use alternate versions
    ## to check for sortedness
    #@assert issorted(data)

    ## Reverse sorted
    reverse!(data)
    gc()
    times["\\sort"] = @elapsed tsort!(data)
    #@assert issorted(data)

    ## Sorted
    gc()
    times["/sort"] = @elapsed tsort!(data)
    #@assert issorted(data)

    ## Sorted with 3 exchanges
    for i = 1:3
        n1 = randi(n)
        n2 = randi(n)
        data[n1], data[n2] = data[n2], data[n1]
    end
    gc()
    times["3sort"] = @elapsed tsort!(data)
    #@assert issorted(data)

    ## Sorted with 10 unsorted values at end
    data[end-9:end] = randfn(10)
    gc()
    times["+sort"] = @elapsed tsort!(data)
    #@assert issorted(data)

    ## Random data with 4 unique values
    data = data[randi(4, n)]
    gc()
    times["~sort"] = @elapsed tsort!(data)
    #@assert issorted(data)

    ## All values equal
    data = data[ones(Int, n)]
    gc()
    times["=sort"] = @elapsed tsort!(data)
    #@assert issorted(data)

    ## quicksort median killer: first half descending, second half ascending
    if qsort_med_killer && (!begins_with(string(sort!), "quick") || n < 2^16)
        data = sort!(randfn(div(n,2)))
        data = vcat(reverse(data), data)
        gc()
        times["!sort"] = @elapsed tsort!(data)
        #@assert issorted(data)
    end

    times
end

sortperf(tsort!::Function, n::Int) = sortperf(tsort!, n, true, rand)
sortperf(tsort!::Function, n::Int, randfn::Function) = sortperf(tsort!, n, true, randfn)
sortperf(tsort!::Function, n::Int, qsort_med_killer::Bool) = sortperf(tsort!, n, qsort_med_killer, rand)


# Run sort tests on a set of sort functions
function run_sort_tests(log2range::Ranges, replicates::Int, sorts::Vector, qsort_med_killer::Bool)
    
    times = Dict[]
    for (tt_name, test_type) in Any[(string(Int), randint_fn(10)), 
                                    (string(Float64), rand), 
                                    ("String[5]", randstr_fn(5)),
                                    ("String[10]", randstr_fn(10))]
        println("Testing $tt_name...")
        for logsize in log2range
            println("  $logsize")
            size = 2^logsize
            for s! in sorts
                if size > 2^18 && s! == quicksort! && begins_with(tt_name, "String")
                    println("Skipping $(s!)")
                    continue
                end
                println("    $(s!)")
                print("      ")

                if (begins_with(string(s!), "insertionsort") && logsize >= 14)
                    println("Skipped")
                    continue
                end

                # replicate
                for i = 1:replicates
                    print(i, " "); flush(stdout_stream)
                    rec = {"test_type"=>tt_name, "sort_fn"=>string(s!), "log_size"=>logsize, "size"=>size}
                    merge!(rec, sortperf(s!, size, qsort_med_killer, test_type))
                    push(times, rec)
                end
                println()
            end
        end
    end

    times

    labels = ["test_type", "sort_fn", "log_size", "size", "*sort", 
              "\\sort", "/sort", "3sort", "+sort", "~sort", "=sort"]

    if qsort_med_killer
        push(labels, "!sort")
    end

    df = DataFrame(times, labels)

end

sort_funcs = [sort!, quicksort!, mergesort!, timsort!, insertionsort!]

run_sort_tests() = run_sort_tests(15)
run_sort_tests(log2val::Int, args...) = run_sort_tests(log2val:log2val, args...)
run_sort_tests(log2range::Ranges) = run_sort_tests(log2range, 1, sort_funcs)
run_sort_tests(log2range::Ranges, replicates::Int) = run_sort_tests(log2range, replicates, sort_funcs)
run_sort_tests(log2range::Ranges, replicates::Int, sort_func::Function, args...) = 
    run_sort_tests(log2range, replicates, [sort_func], args...)
run_sort_tests(log2range::Ranges, replicates::Int, sorts::Vector) = run_sort_tests(log2range, replicates, sorts, false)

        

sort_descr = [ '*' => "random", 
               '\\' => "reversed",
               '/' => "sorted",
               '3' => "3 exchanges",
               '+' => "10 appended",
               '~' => "4 unique items",
               '=' => "all equal",
               '!' => "qsort median killer"]

# Create sort plots
function sort_plots(df, cols)
    plots = Any[]
    colors = repmat(["black", "blue", "green", "red", "cyan", "magenta"], 3, 1)
    linestyles = repmat(["solid", "dotted", "dotdashed"]', 6, 1)[:]
    for test_type_df in groupby(df, "test_type")
        test = test_type_df[1, "test_type"]

        for col in cols
            seq = split(col, '_')[1]
            seq_name = sort_descr[seq[1]]

            ts = "$(test)_$(seq_name)" | x -> replace(x, r"[ \[]", "_") | x -> replace(x, '\]', "")

            println("Plotting $ts")
            plt = FramedPlot()
            setattr(plt, "xlabel", L"log n")
            setattr(plt, "ylabel", "time (sec)")
            setattr(plt, "title", "Sort Comparison ($test, $seq_name)")
            setattr(plt.y1, "log", true )
            setattr(plt, "width", 768)

            curves = Any[]
            for (i, sort_fn_df) in enumerate(groupby(test_type_df, "sort_fn"))
                sort_fn = sort_fn_df[1, "sort_fn"]
                c = colors[i]
                s = linestyles[i]
                pts = Points(sort_fn_df["log_size"], sort_fn_df[col], "color", c, "symboltype", "circle")
                cv = Curve(sort_fn_df["log_size"], sort_fn_df[col], "color", c, "linestyle", s)
                setattr(cv, "label", replace(sort_fn, "_", "\\_"))
                push(curves, cv)
                add(plt, pts)
                add(plt, cv)
            end
            add(plt, Legend(.1, .9, curves))

            push(plots, plt)
        end
    end

    plots
end

# Test standard sort functions
function std_sort_tests(save_plots::Bool, pdffile)
    sort_times = run_sort_tests(6:20, 5, [sort!, quicksort!, mergesort!, timsort!, insertionsort!], true)
    sort_times_median = groupby(sort_times, ["log_size", "size", "sort_fn", "test_type"]) | :median

    if save_plots
        plots = sort_plots(sort_times_median, ["*sort_median", "\\sort_median", "/sort_median", "3sort_median",
                                               "+sort_median", "~sort_median", "=sort_median", "!sort_median"])
        file(plots, pdffile)
    end
    sort_times_median
end

std_sort_tests() = std_sort_tests(false, "")
std_sort_tests(save_plots::Bool) = std_sort_tests(save_plots, "sortperf.pdf")


# Test sorts returning a permutation
function perm_sort_tests(save_plots::Bool, pdffile)
    sort_times = run_sort_tests(6:20, 5, [Base.mergesort_perm!, 
                                          Base.timsort_perm!, 
                                          Base.insertionsort_perm!], 
                                true)
    sort_times_median = groupby(sort_times, ["log_size", "size", "sort_fn", "test_type"]) | :median

    if save_plots
        plots = sort_plots(sort_times_median, ["*sort_median", "\\sort_median", "/sort_median", "3sort_median",
                                               "+sort_median", "~sort_median", "=sort_median", "!sort_median"])
        file(plots, pdffile)
    end
    sort_times_median
end

perm_sort_tests() = perm_sort_tests(false, "")
perm_sort_tests(save_plots::Bool) = perm_sort_tests(save_plots, "sortperf_perm.pdf")


end # module SortPerf
