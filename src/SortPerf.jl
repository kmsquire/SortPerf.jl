## modeled after sort tests in python's sortperf.py
##
## Kevin Squire
##

module SortPerf

export sortperf, run_sort_tests, sort_plots, std_sort_tests, perm_sort_tests

import Base.Sort: InsertionSort, QuickSort, MergeSort, TimSort, Algorithm

using DataFrames
using Winston

#require("Winston/src/Plot")
#using Plot

randstr_fn(str_len::Int) = n -> [randstring(str_len) for i = 1:n]
randint_fn(m::Int) = n -> rand(1:m,n)

sort_algs = [InsertionSort, QuickSort, MergeSort, TimSort]
Reverse = Base.Sort.ReverseOrdering(Sort.Forward)

function sortperf(alg::Algorithm, data, qsort_med_killer::Bool=true)
    
    srand(1)
    times = Dict{String, Float64}()
    n = length(data)

    ## Random
    gc()
    times["*sort"] = @elapsed sort!(data, alg=alg)
    @assert issorted(data)

    ## Reverse sorted
    reverse!(data)
    @assert issorted(data, Reverse)
    gc()
    times["\\sort"] = @elapsed sort!(data, alg=alg)
    @assert issorted(data)

    ## Sorted
    gc()
    times["/sort"] = @elapsed sort!(data, alg=alg)
    @assert issorted(data)

    ## Sorted with 3 exchanges
    for i = 1:3
        n1 = rand(1:n)
        n2 = rand(1:n)
        data[n1], data[n2] = data[n2], data[n1]
    end
    gc()
    times["3sort"] = @elapsed sort!(data, alg=alg)
    @assert issorted(data)

    ## Sorted with 10 unsorted values at end
    for i = 1:10
        val = splice!(data, i:i)
        append!(data, val)
    end
    gc()
    times["+sort"] = @elapsed sort!(data, alg=alg)
    @assert issorted(data)

    ## Random data with 4 unique values
    idxs = Int[]
    for i = 1:4
        idx = rand(1:n)
        while contains(idxs, idx)
            idx = rand(1:n)
        end
        push!(idxs, i)
    end
    vals = data[idxs]
    data4 = vals[rand(1:4, n)]
    gc()
    times["~sort"] = @elapsed sort!(data4, alg=alg)
    @assert issorted(data)

    ## All values equal
    data1 = data[fill(rand(1:n), n)]
    gc()
    times["=sort"] = @elapsed sort!(data, alg=alg)
    @assert issorted(data)

    ## quicksort median killer: first half descending, second half ascending
    if qsort_med_killer && (alg!=QuickSort || n <= 2^18)
        last = (length(data)>>1)<<1 # make sure data length is even
        qdata = vcat(data[last:-2:2], data[1:2:last])
        gc()
        times["!sort"] = @elapsed sort!(qdata, alg=alg)
        @assert issorted(data)
    end

    times
end

sortperf(alg::Algorithm, n::Int) = sortperf(alg, n, true, rand)
sortperf(alg::Algorithm, n::Int, randfn::Function) = sortperf(alg, n, true, randfn)
sortperf(alg::Algorithm, n::Int, qsort_med_killer::Bool) = sortperf(alg, n, qsort_med_killer, rand)

sortperf(alg::Algorithm, n::Int, qsort_med_killer::Bool, randfn::Function) =
    sortperf(alg, randfn(n), qsort_med_killer)


# Run sort tests on a set of sort functions
function run_sort_tests(log2range::Ranges, replicates::Int, sorts::Vector, qsort_med_killer::Bool)
    
    times = Dict[]
    for (tt_name, test_type) in Any[(string(Int), randint_fn(10)), 
                                    (string(Float64), rand), 
                                    ("String[10]", randstr_fn(10))]
        println("Testing $tt_name...")
        for logsize in log2range
            println("  $logsize")
            size = 2^logsize
            for s in sorts
                if size > 2^18 && s == QuickSort && beginswith(tt_name, "String")
                    println("Skipping $(s)")
                    continue
                end
                println("    $s")
                print("      ")

                if (s == InsertionSort && logsize >= 14)
                    println("Skipped")
                    continue
                end

                # replicate
                for i = 1:replicates
                    print(i, " ")
                    rec = {"test_type"=>tt_name, "sort_alg"=>string(s)[1:end-5], "log_size"=>logsize, "size"=>size}
                    merge!(rec, sortperf(s, size, qsort_med_killer, test_type))
                    push!(times, rec)
                end
                println()
            end
        end
    end

    times

    labels = ["test_type", "sort_alg", "log_size", "size", "*sort", 
              "\\sort", "/sort", "3sort", "+sort", "~sort", "=sort"]

    if qsort_med_killer
        push!(labels, "!sort")
    end

    df = DataFrame(times, labels)

end

run_sort_tests() = run_sort_tests(15)
run_sort_tests(log2val::Int, args...) = run_sort_tests(log2val:log2val, args...)
run_sort_tests(log2range::Ranges) = run_sort_tests(log2range, 1, sort_algs)
run_sort_tests(log2range::Ranges, replicates::Int) = run_sort_tests(log2range, replicates, sort_algs)
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
    plots = PlotContainer[]
    colors = repmat(["black", "blue", "green", "red", "cyan", "magenta"], 3, 1)
    linestyles = repmat(["solid", "dotted", "dotdashed"]', 6, 1)[:]
    for test_type_df in groupby(df, "test_type")
        test = test_type_df[1, "test_type"]

        for col in cols
            seq = split(col, '_')[1]
            seq_name = sort_descr[seq[1]]

            ts = "$(test)_$(seq_name)" |> x -> replace(x, r"[ \[]", "_") |> x -> replace(x, '\]', "")

            println("Plotting $ts")
            plt = FramedPlot()
            setattr(plt, "xlabel", "log n")
            setattr(plt, "ylabel", "time (sec)")
            setattr(plt, "title", "Sort Comparison ($test, $seq_name)")
            setattr(plt.y1, "log", true )
            setattr(plt, "width", 768)

            curves = Any[]
            for (i, sort_alg_df_all) in enumerate(groupby(test_type_df, "sort_alg"))
                sort_alg_df = sort_alg_df_all[complete_cases(sort_alg_df_all),:]
                sort_alg = sort_alg_df[1, "sort_alg"]
                c = colors[i]
                s = linestyles[i]
                pts = Points(sort_alg_df["log_size"], sort_alg_df[col], "color", c, "symboltype", "circle")
                cv = Curve(sort_alg_df["log_size"], sort_alg_df[col], "color", c, "linestyle", s)
                setattr(cv, "label", replace(sort_alg, "_", "\\_"))
                push!(curves, cv)
                add(plt, pts)
                add(plt, cv)
            end
            add(plt, Legend(.1, .9, curves))

            push!(plots, plt)
        end
    end

    plots
end

# Test standard sort functions
function std_sort_tests(save_plots::Bool=false, pdffile="sortperf.pdf")
    sort_times = run_sort_tests(6:2:20, 3, sort_algs, true)
    sort_times_median = groupby(sort_times, ["log_size", "size", "sort_alg", "test_type"]) |> :median

    if save_plots
        plots = sort_plots(sort_times_median, ["*sort_median", "\\sort_median", "/sort_median", "3sort_median",
                                               "+sort_median", "~sort_median", "=sort_median", "!sort_median"])
        file(plots, pdffile)
    end
    sort_times_median
end

end # module SortPerf
