## modeled after sort tests in python's sortperf.py
##
## Kevin Squire
##

module SortPerf

export sortperf, sort_plots, view_sort_plots, save_sort_plots, std_sort_tests, sort_median, sort_scale

import Base.Sort: Algorithm, Forward, ReverseOrdering, ord
import Base.Order.Ordering


using SortingAlgorithms
using DataFrames
using Winston
using Color

# rand functions for testing
randstr(n::Int) = [randstring() for i = 1:n]
randint(n::Int) = rand(1:n,n)

randfns = (Type=>Function)[Int => randint, 
                           Int32 => x->int32(randint(x)),
                           Int64 => x->int64(randint(x)), 
                           Int128 => x->int128(randint(x)),
                           Float32 => x->float32(rand(x)), 
                           Float64 => rand, 
                           String => randstr]

std_types = [Int, Float64, String]
sort_algs = [InsertionSort, HeapSort, MergeSort, QuickSort, RadixSort, TimSort] #, TimSortUnstable]

# DataFrame labels
labels = ["test_type", "sort_alg", "log_size", "size", "*sort", 
          "\\sort", "/sort", "3sort", "+sort", "~sort", "=sort", "!sort"]

# Corresponding descriptions
sort_descr = [ '*' => "random", 
               '\\' => "reversed",
               '/' => "sorted",
               '3' => "3 exchanges",
               '+' => "10 appended",
               '~' => "4 unique items",
               '=' => "all equal",
               '!' => "qsort median killer"]


# Test algorithm performance on a data vector
function _sortperf(alg::Algorithm, origdata::Vector, order::Ordering=Forward; replicates=3, skip_median_killer=false)
    srand(1)
    times = Dict[]   # Array of Dicts!
    n = length(origdata)
    logn = log2(length(origdata))

    rec = {"test_type" => string(eltype(origdata)), 
           "sort_alg" => string(alg)[1:end-5], 
           "log_size" => isinteger(logn) ? int(logn) : logn, 
           "size" => length(origdata)}

    if alg==RadixSort && !isbits(origdata[1])
        println("Skipping RadixSort for non bitstype $(eltype(origdata))")
        reptimes = Dict{String, Float64}()
        for label in labels[5:end]
            reptimes[label] = 0.0
        end
        return times
    end

    for rep = 1:replicates
        print(" $rep")
        reptimes = Dict{String, Float64}()

        ## Random
        data = copy(origdata)
        gc()
        if !issorted(data, order)
            reptimes["*sort"] = @elapsed sort!(data, alg, order)
            @assert issorted(data, order)
        end

        ## Sorted
        gc()
        reptimes["/sort"] = @elapsed sort!(data, alg, order)
        @assert issorted(data, order)

        ## Reverse sorted
        reverse!(data)
        @assert issorted(data, ReverseOrdering(order))
        gc()
        reptimes["\\sort"] = @elapsed sort!(data, alg, order)
        @assert issorted(data, order)

        ## Sorted with 3 exchanges
        for i = 1:3
            n1 = rand(1:n)
            n2 = rand(1:n)
            data[n1], data[n2] = data[n2], data[n1]
        end
        gc()
        reptimes["3sort"] = @elapsed sort!(data, alg, order)
        @assert issorted(data, order)

        ## Sorted with 10 unsorted values at end
        if length(data) >= 20
            for i = 1:10
                val = splice!(data, i:i)
                append!(data, val)
            end
            gc()
            reptimes["+sort"] = @elapsed sort!(data, alg, order)
            @assert issorted(data, order)
        end

        ## Random data with 4 unique values
        idxs = Int[]
        for i = 1:4
            idx = rand(1:n)
            while idx in idxs
                idx = rand(1:n)
            end
            push!(idxs, idx)
        end
        vals = data[idxs]
        data4 = vals[rand(1:4, n)]
        gc()
        reptimes["~sort"] = @elapsed sort!(data4, alg, order)
        @assert issorted(data, order)

        ## All values equal
        data1 = data[fill(rand(1:n), n)]
        gc()
        reptimes["=sort"] = @elapsed sort!(data1, alg, order)
        @assert issorted(data1, order)

        ## quicksort median killer: first half descending, second half ascending
        if skip_median_killer || alg==QuickSort && !(eltype(data) <: Integer) && length(data) >= 2^18
            print("(median killer skipped) ")
        else
            last = (length(data)>>1)<<1 # make sure data length is even
            qdata = vcat(data[last:-2:2], data[1:2:last])
            gc()
            reptimes["!sort"] = @elapsed sort!(qdata, alg, order)
            @assert issorted(qdata, order)
        end

        push!(times, merge(rec, reptimes))
    end
    println()

    times
end

# run sortperf over a range of data lengths
function _sortperf(alg::Algorithm, data::Vector, log2range::Ranges, order::Ordering=Forward; named...)
    lg2range = filter(x -> 2^x <= length(data), [log2range])
    times = Dict[]
    for logsize in lg2range
        println("  $logsize")
        size = 2^logsize
        if (alg == InsertionSort && logsize >= 14)
            println("Skipped")
            continue
        end

        append!(times, _sortperf(alg, data[1:size], order; named...))
    end

    times
end

# Generate a random array and run sortperf
function _sortperf(alg::Algorithm, T::Type, size::Int, args...; named...)
    println("Testing $T...")
    _sortperf(alg, randfns[T](size), args...; named...)
end

# Generate a random array and run sortperf over different ranges of that array
function _sortperf(alg::Algorithm, T::Type, log2range::Ranges, args...; named...)
    println("Testing $T...")
    _sortperf(alg, randfns[T](2^last(log2range)), log2range, args...; named...)
end

# Run sortperf for a number of types
function _sortperf(alg::Algorithm, types::Vector{DataType}, args...; named...)
    times = Dict[]
    for T in types
        append!(times, _sortperf(alg, T, args...; named...))
    end
    times
end

# Run sortperf on a number of algorithms
function _sortperf(algs::Vector{Algorithm}, args...; named...)
    times = Dict[]
    for alg in algs
        println("\n$alg\n")
        append!(times, _sortperf(alg, args...; named...))
    end
    times
end

# Returns a DataFrame version of sortperf output
sortperf(args...; named...) = DataFrame(_sortperf(args...; named...), labels)

# Get median sort timings
sort_median(df::DataFrame) = groupby(df, ["log_size", "size", "sort_alg", "test_type"]) |> :median

sort_scale(df::DataFrame, base_sort) = by(df, ["log_size", "size", "test_type"], 
                                          x->(row = find(x["sort_alg"] .== base_sort);
                                              ht = size(x,1); 
                                              hcat(x[:,3:3],x[:,5:end]./vcat(rep(x[row,5:end],ht)...))))

# Create sort plots
function sort_plots(df, base_sort, cols = ["*sort_median", "\\sort_median", "/sort_median", "3sort_median",
                                           "+sort_median", "~sort_median", "=sort_median", "!sort_median"])
    plots = PlotContainer[]
    sort_algs = unique(df["sort_alg"])
    dc = distinguishable_colors(12)[[1,3,4,5,6,7,8,9,10,11,12]]
    colors = Dict([string(alg) for alg in sort_algs], Uint32[convert(RGB24, r) for r in dc])
    linestyles = repmat(["solid", "dotted", "dotdashed"]', 6, 1)[:]
    for test_type_df in groupby(df, "test_type")
        test = test_type_df[1, "test_type"]

        for col in cols
            if length(DataFrames.removeNA(df[col])) == 0; continue; end

            seq = split(col, '_')[1]
            seq_name = sort_descr[seq[1]]

            ts = "$(test)_$(seq_name)" |> x -> replace(x, r"[ \[]", "_") |> x -> replace(x, '\]', "")

            println("Plotting $ts")
            plt = FramedPlot()
            setattr(plt, "xlabel", "log n")
            setattr(plt, "ylabel", "time (relative to $base_sort")
            setattr(plt, "title", "Sort Comparison ($test, $seq_name)")
            #setattr(plt.y1, "log", true )
            setattr(plt, "yrange", (0, 1.35))
            setattr(plt, "width", 768)

            curves = Any[]
            for (i, sort_alg_df_all) in enumerate(groupby(test_type_df, "sort_alg"))
                sort_alg_df = sort_alg_df_all[complete_cases(sort_alg_df_all[:,[col]]),:]
                sort_alg = sort_alg_df[1, "sort_alg"]
                c = colors[sort_alg]
                s = linestyles[i]
                pts = Points(sort_alg_df["log_size"], sort_alg_df[col], "color", c, "symboltype", "circle")
                cv = Curve(sort_alg_df["log_size"], sort_alg_df[col], "color", c, "linestyle", s)
                setattr(cv, "label", replace(sort_alg, "_", "\\_"))
                push!(curves, cv)
                add(plt, pts)
                if length(sort_alg_df["log_size"]) > 1
                    add(plt, cv)
                end
            end

            add(plt, Legend(.1, .9, curves))

            push!(plots, plt)
        end
    end

    plots
end

# Save plots
save_sort_plots(plots, pdffile="sortperf.pdf") = file(plots, pdffile)
#save_sort_plots(df::DataFrame, pdffile="sortperf.pdf") = 
#    save_sort_plots(sort_plots(sort_median(df), ["*sort_median", "\\sort_median", "/sort_median", "3sort_median",
#                                                 "+sort_median", "~sort_median", "=sort_median", "!sort_median"]),
#                               pdffile)
save_sort_plots(df::DataFrame, base_sort, pdffile="sortperf.pdf") = 
    save_sort_plots(sort_plots(sort_scale(sort_median(df), base_sort), base_sort), pdffile)

function view_sort_plots(plots)
    for p in plots
        Winston.display(p)
    end
end

# Test standard sort functions
function std_sort_tests(;sort_algs=SortPerf.sort_algs, types=SortPerf.std_types, range=6:20, replicates=3,
                        lt::Function=isless, by::Function=identity, rev::Bool=false, order::Ordering=Forward, 
                        save::Bool=false, prefix="sortperf", skip_median_killer=false, base_sort="QuickSort")
    sort_times = sortperf(sort_algs, types, range, ord(lt,by,rev,order); 
                          replicates=replicates, skip_median_killer=skip_median_killer)

    if save
        pdffile = prefix*".pdf"
        tsvfile = prefix*".tsv"
        save_sort_plots(sort_times, base_sort, pdffile)
        writetable(tsvfile, sort_times)
    end

    sort_times
end

end # module SortPerf
