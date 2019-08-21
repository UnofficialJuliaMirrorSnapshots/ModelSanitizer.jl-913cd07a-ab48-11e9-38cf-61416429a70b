import LibGit2
import PkgBenchmark

# include("./utils/github/_httpjson_github_api_unauthenticated.jl")
# include("./utils/github/_httpjson_github_api_authenticated.jl")

struct AllowedToIgnoreThisError end

_single_line_travis_ignore_errors(x::AbstractString) = _single_line_travis_ignore_errors(convert(String, x))

function _single_line_travis_ignore_errors(line::String)::Bool
    _line::String = strip(line)
    _regex_ignore_errors = r"^\d*: \[IGNORE_ERRORS_BENCHMARK_STAGE\]"
    ignore_errors::Bool = occursin(_regex_ignore_errors, _line)
    return ignore_errors
end

travis_ignore_errors(x::AbstractString) = travis_ignore_errors(convert(String, x))

function travis_ignore_errors(commit_message::String)::Bool
    lines::Vector{String} = split(strip(commit_message), "\n")
    vector_ignore_errors::Vector{Bool} = Vector{Bool}(undef, 0)
    for line in lines
        _line = strip(line)
        if isempty(_line)
        elseif startswith(_line, "Merge #")
        elseif startswith(_line, "Try #")
        elseif startswith(_line, "Co-authored-by:")
        else
            line_ignore_errors = _single_line_travis_ignore_errors(_line)
            push!(vector_ignore_errors, line_ignore_errors)
        end
    end
    ignore_errors = _all_and_notempty(vector_ignore_errors)
    return ignore_errors
end

function get_travis_git_commit_message(a::AbstractDict = ENV)::String
    result::String = strip(get(a, "TRAVIS_COMMIT_MESSAGE", ""))
    return result
end

_single_line_travis_allow_regressions(x::AbstractString) = _single_line_travis_allow_regressions(convert(String, x))

function _single_line_travis_allow_regressions(line::String)::Tuple{Bool, Bool}
    _line::String = strip(line)
    _regex_allow_onlytime_regressions = r"^\d*: \[ALLOW_TIME_REGRESSIONS\]"
    _regex_allow_onlymemory_regressions = r"^\d*: \[ALLOW_MEMORY_REGRESSIONS\]"
    _regex_allow_bothtimeandmemory_regressions = r"^\d*: \[ALLOW_TIME\+MEMORY_REGRESSIONS\]"
    _allow_onlytime_regressions::Bool = occursin(_regex_allow_onlytime_regressions, _line)
    _allow_onlymemory_regressions::Bool = occursin(_regex_allow_onlymemory_regressions, _line)
    _allow_bothtimeandmemory_regressions::Bool = occursin(_regex_allow_bothtimeandmemory_regressions, _line)
    allow_time_regressions::Bool = _allow_onlytime_regressions || _allow_bothtimeandmemory_regressions
    allow_memory_regressions::Bool = _allow_onlymemory_regressions || _allow_bothtimeandmemory_regressions
    return allow_time_regressions, allow_memory_regressions
end

travis_allow_regressions(x::AbstractString) = travis_allow_regressions(convert(String, x))

_all_and_notempty(x) = !isempty(x) && all(x)

function travis_allow_regressions(commit_message::String)::Tuple{Bool, Bool}
    lines::Vector{String} = split(strip(commit_message), "\n")
    vector_allow_time_regressions::Vector{Bool} = Vector{Bool}(undef, 0)
    vector_allow_memory_regressions::Vector{Bool} = Vector{Bool}(undef, 0)
    for line in lines
        _line = strip(line)
        if isempty(_line)
        elseif startswith(_line, "Merge #")
        elseif startswith(_line, "Try #")
        elseif startswith(_line, "Co-authored-by:")
        else
            line_allow_time_regressions, line_allow_memory_regressions = _single_line_travis_allow_regressions(_line)
            push!(vector_allow_time_regressions, line_allow_time_regressions)
            push!(vector_allow_memory_regressions, line_allow_memory_regressions)
        end
    end
    allow_time_regressions = _all_and_notempty(vector_allow_time_regressions)
    allow_memory_regressions = _all_and_notempty(vector_allow_memory_regressions)
    return allow_time_regressions, allow_memory_regressions
end

function pkgbenchmark_judge(pkg_name, target, baseline)
    judgement = PkgBenchmark.judge(pkg_name, target, baseline)
    return judgement
end

function pkgbenchmark_judge_ignore_errors(pkg_name, target, baseline)
    try
        judgement = PkgBenchmark.judge(pkg_name, target, baseline)
        return judgement
    catch ex
        showerror(stderr, ex)
        Base.show_backtrace(stderr, catch_backtrace())
        println(stderr)
        return AllowedToIgnoreThisError()
    end
end

function all_versions(repo_path::AbstractString)
    _repo_path::String = strip(repo_path)
    _repo = LibGit2.GitRepoExt(_repo_path)
    _ref_list = LibGit2.ref_list(_repo)
    _all_versions = Vector{VersionNumber}(undef, 0)
    for _ref in _ref_list
        if occursin(r"^refs\/tags\/v(\d*).(\d*).(\d*)$", _ref)
            _m = match(r"^refs\/tags\/v(\d*).(\d*).(\d*)$", _ref)
            _v = VersionNumber("$(_m[1]).$(_m[2]).$(_m[3])")
            push!(_all_versions, _v)
        end
    end
    unique!(_all_versions)
    sort!(_all_versions)
    return _all_versions
end

latest_semver_version(repo_path) = maximum(all_versions(repo_path))

function _run_benchmarks(
        ;
        target::Union{String, PkgBenchmark.BenchmarkConfig},
        baseline::Union{String, PkgBenchmark.BenchmarkConfig},
        )::Nothing
    # git_commit_message::String = _httpjson_get_github_pull_request_title_unauthenticated()
    # git_commit_message::String = _httpjson_get_github_pull_request_title_authenticated()
    git_commit_message::String = get_travis_git_commit_message()

    ignore_errors = travis_ignore_errors(git_commit_message)
    allow_time_regressions, allow_memory_regressions = travis_allow_regressions(git_commit_message)

    @info("Ignore errors during the benchmark suite: $(ignore_errors)")
    @info("Allow time regressions: $(allow_time_regressions)")
    @info("Allow memory regressions: $(allow_memory_regressions)")
    @info("Target: $(target)")
    @info("Baseline: $(baseline)")

    project_root = dirname(dirname(@__FILE__))

    proof_of_concept_dataframes = joinpath(project_root, "test", "integration-tests", "test-proof-of-concept-dataframes.jl")
    proof_of_concept_linearmodel = joinpath(project_root, "test", "integration-tests", "test-proof-of-concept-linearmodel.jl")
    proof_of_concept_mlj = joinpath(project_root, "test", "integration-tests", "test-proof-of-concept-mlj.jl")

    # run each of the scripts once to force compilation of the functions
    include(proof_of_concept_dataframes)
    include(proof_of_concept_linearmodel)
    include(proof_of_concept_mlj)

    if ignore_errors
        judgement = pkgbenchmark_judge_ignore_errors("ModelSanitizer", target, baseline)
    else
        judgement = pkgbenchmark_judge("ModelSanitizer", target, baseline)
    end

    if judgement isa AllowedToIgnoreThisError
    else
        this_judgement_was_failed_for_time = false
        this_judgement_was_failed_for_memory = false

        for i in ["integration-tests"]
            for j in ["proof-of-concept-dataframes", "proof-of-concept-linearmodel", "proof-of-concept-mlj"]
                trial_judgement = PkgBenchmark.benchmarkgroup(judgement).data[i].data[j]
                if PkgBenchmark.time(trial_judgement) == :regression
                    if allow_time_regressions
                        @error("Time regression (allowed) detected in $(i)/$(j)", trial_judgement)
                    else
                        this_judgement_was_failed_for_time = true
                        @error("Time regression detected in $(i)/$(j)", trial_judgement)
                    end
                end
                if PkgBenchmark.memory(trial_judgement) == :regression
                    if allow_memory_regressions
                        @error("Memory regression (allowed) detected in $(i)/$(j)", trial_judgement)
                    else
                        this_judgement_was_failed_for_memory = true
                        @error("Memory regression regression detected in $(i)/$(j)", trial_judgement)
                    end
                end
            end
        end

        if this_judgement_was_failed_for_time || this_judgement_was_failed_for_memory
            error_message = string("FAILURE: ",
                                   "One or more fatal performance ",
                                   "performance regressions were detected.\n",
                                   "To ignore only time regressions, ",
                                   "begin your pull request title with ",
                                   "\"",
                                   "[ALLOW_TIME_REGRESSIONS]",
                                   "\" (without the quotation marks).\n",
                                   "To ignore only memory regressions, ",
                                   "begin your pull request title with ",
                                   "\"",
                                   "[ALLOW_MEMORY_REGRESSIONS]",
                                   "\".\n",
                                   "To ignore both time and memory regressions, ",
                                   "begin your pull request title with ",
                                   "\"",
                                   "[ALLOW_TIME+MEMORY_REGRESSIONS]",
                                   "\".\n")
            travis_branch = lowercase(strip(get(ENV, "TRAVIS_BRANCH", "")))
            travis_pull_request = lowercase(strip(get(ENV, "TRAVIS_PULL_REQUEST", "")))
            if travis_branch == "trying" && travis_pull_request == "false"
                @error(error_message)
            else
                error(error_message)
            end
        else
            @info("SUCCESS: No fatal performance regressions were detected.")
        end
    end
    return nothing
end

function run_benchmarks(repo_path = pwd())::Nothing
    travis_branch::String = lowercase(strip(get(ENV, "TRAVIS_BRANCH", "")))
    travis_pull_request::String = lowercase(strip(get(ENV, "TRAVIS_PULL_REQUEST", "")))
    latest_version::String = string("v", latest_semver_version(repo_path))
    target::String = "HEAD"
    if travis_branch == "master" && travis_pull_request == "false"
        baseline = latest_version
    else
        baseline = "master"
    end
    _run_benchmarks(; target = target, baseline = baseline)
    return nothing
end

run_benchmarks()
