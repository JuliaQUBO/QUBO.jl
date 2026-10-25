#!/usr/bin/env julia

module ZenodoReleaseVerification

const _Downloads = Base.require(
    Base.PkgId(Base.UUID("f43a241f-c20a-4ad4-852c-f6b1247861c6"), "Downloads"),
)

const CONCEPT_RECORD_ID = "7909165"
const CONCEPT_DOI = "10.5281/zenodo.$CONCEPT_RECORD_ID"
const DEFAULT_API_URL = "https://zenodo.org/api/records/$CONCEPT_RECORD_ID/versions/latest"

function _skip_ws(s::AbstractString, i::Int, n::Int)
    while i <= n && s[i] in (' ', '\t', '\r', '\n')
        i = nextind(s, i)
    end
    return i
end

function _parse_json_string(s::AbstractString, i::Int, n::Int)
    i <= n && s[i] == '"' || error("Expected '\"' at byte $i.")
    i = nextind(s, i)
    buf = IOBuffer()
    while i <= n
        c = s[i]
        if c == '"'
            return String(take!(buf)), nextind(s, i)
        elseif c == '\\'
            i = nextind(s, i)
            i <= n || error("Unterminated escape sequence in JSON string.")
            esc = s[i]
            if esc == '"' || esc == '\\' || esc == '/'
                write(buf, esc)
                i = nextind(s, i)
            elseif esc == 'b'
                write(buf, '\b')
                i = nextind(s, i)
            elseif esc == 'f'
                write(buf, '\f')
                i = nextind(s, i)
            elseif esc == 'n'
                write(buf, '\n')
                i = nextind(s, i)
            elseif esc == 'r'
                write(buf, '\r')
                i = nextind(s, i)
            elseif esc == 't'
                write(buf, '\t')
                i = nextind(s, i)
            elseif esc == 'u'
                i = nextind(s, i)
                code = _parse_hex4(s, i, n)
                i = _advance_n(s, i, 4)
                if 0xD800 <= code <= 0xDBFF && i <= n && s[i] == '\\'
                    i2 = nextind(s, i)
                    if i2 <= n && s[i2] == 'u'
                        i3 = nextind(s, i2)
                        low = _parse_hex4(s, i3, n)
                        if 0xDC00 <= low <= 0xDFFF
                            cp = 0x10000 + ((UInt32(code - 0xD800) << 10) | UInt32(low - 0xDC00))
                            write(buf, Char(cp))
                            i = _advance_n(s, i3, 4)
                            continue
                        end
                    end
                end
                write(buf, Char(code))
            else
                error("Invalid JSON escape '\\$esc'.")
            end
        else
            write(buf, c)
            i = nextind(s, i)
        end
    end
    error("Unterminated JSON string.")
end

function _parse_hex4(s::AbstractString, i::Int, n::Int)
    val = UInt16(0)
    for _ in 1:4
        i <= n || error("Truncated \\u escape in JSON string.")
        c = s[i]
        d = if '0' <= c <= '9'
            UInt16(c - '0')
        elseif 'a' <= c <= 'f'
            UInt16(c - 'a' + 10)
        elseif 'A' <= c <= 'F'
            UInt16(c - 'A' + 10)
        else
            error("Invalid hex digit '$c' in \\u escape.")
        end
        val = (val << 4) | d
        i = nextind(s, i)
    end
    return val
end

function _advance_n(s::AbstractString, i::Int, count::Int)
    for _ in 1:count
        i = nextind(s, i)
    end
    return i
end

function _parse_json_value(s::AbstractString, i::Int, n::Int)
    i = _skip_ws(s, i, n)
    i <= n || error("Unexpected end of JSON input.")
    c = s[i]
    if c == '"'
        return _parse_json_string(s, i, n)
    elseif c == '{'
        i = _skip_ws(s, nextind(s, i), n)
        obj = Dict{String,Any}()
        if i <= n && s[i] == '}'
            return obj, nextind(s, i)
        end
        while true
            i = _skip_ws(s, i, n)
            k, i = _parse_json_string(s, i, n)
            i = _skip_ws(s, i, n)
            i <= n && s[i] == ':' || error("Expected ':' after object key at byte $i.")
            v, i = _parse_json_value(s, nextind(s, i), n)
            obj[k] = v
            i = _skip_ws(s, i, n)
            if i <= n && s[i] == ','
                i = nextind(s, i)
            elseif i <= n && s[i] == '}'
                return obj, nextind(s, i)
            else
                error("Expected ',' or '}' in JSON object at byte $i.")
            end
        end
    elseif c == '['
        i = _skip_ws(s, nextind(s, i), n)
        arr = Any[]
        if i <= n && s[i] == ']'
            return arr, nextind(s, i)
        end
        while true
            v, i = _parse_json_value(s, i, n)
            push!(arr, v)
            i = _skip_ws(s, i, n)
            if i <= n && s[i] == ','
                i = nextind(s, i)
            elseif i <= n && s[i] == ']'
                return arr, nextind(s, i)
            else
                error("Expected ',' or ']' in JSON array at byte $i.")
            end
        end
    elseif startswith(SubString(s, i), "true")
        return true, _advance_n(s, i, 4)
    elseif startswith(SubString(s, i), "false")
        return false, _advance_n(s, i, 5)
    elseif startswith(SubString(s, i), "null")
        return nothing, _advance_n(s, i, 4)
    else
        m = match(r"^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?", SubString(s, i))
        m === nothing && error("Invalid JSON token at byte $i.")
        tok = m.match
        num = occursin(r"[.eE]", tok) ? parse(Float64, tok) : parse(Int64, tok)
        return num, i + sizeof(tok)
    end
end

function parse_json(text::AbstractString)
    n = ncodeunits(text)
    val, i = _parse_json_value(text, 1, n)
    i = _skip_ws(text, i, n)
    i > n || error("Trailing content in JSON document at byte $i.")
    return val
end

normalize_version(value) = replace(strip(string(value)), r"^[vV]" => "")

function check_record(record::AbstractDict, expected_tag::AbstractString)
    concept_record_id = string(get(record, "conceptrecid", ""))
    if concept_record_id != CONCEPT_RECORD_ID
        return (
            ok = false,
            message = "Zenodo returned concept record '$concept_record_id', expected '$CONCEPT_RECORD_ID'.",
            doi = nothing,
        )
    end

    metadata = get(record, "metadata", nothing)
    if !(metadata isa AbstractDict) || !haskey(metadata, "version")
        return (
            ok = false,
            message = "Zenodo's latest record does not declare metadata.version.",
            doi = nothing,
        )
    end

    archived_version = string(metadata["version"])
    if normalize_version(archived_version) != normalize_version(expected_tag)
        return (
            ok = false,
            message = "Zenodo's latest version is '$archived_version', expected '$expected_tag'.",
            doi = get(record, "doi", nothing),
        )
    end

    raw_doi = get(record, "doi", nothing)
    version_doi = raw_doi === nothing ? "" : strip(string(raw_doi))
    if isempty(version_doi)
        return (
            ok = false,
            message = "Zenodo's latest record does not declare a version DOI.",
            doi = nothing,
        )
    elseif version_doi == CONCEPT_DOI
        return (
            ok = false,
            message = "Zenodo's latest record DOI '$version_doi' matches the concept DOI '$CONCEPT_DOI' instead of a distinct version DOI.",
            doi = version_doi,
        )
    end

    return (
        ok = true,
        message = "Zenodo record $version_doi matches release '$expected_tag'.",
        doi = version_doi,
    )
end

function fetch_record(url::AbstractString)
    output = IOBuffer()
    response = _Downloads.request(url; output, timeout = 30, throw = false)
    hasproperty(response, :status) || error(sprint(showerror, response))
    response.status == 200 || error("Zenodo returned HTTP $(response.status).")

    return parse_json(String(take!(output)))
end

function verify_release(
    expected_tag::AbstractString;
    api_url::AbstractString = get(ENV, "ZENODO_API_URL", DEFAULT_API_URL),
    attempts::Int = parse(Int, get(ENV, "ZENODO_VERIFY_ATTEMPTS", "12")),
    delay_seconds::Real = parse(Float64, get(ENV, "ZENODO_VERIFY_DELAY_SECONDS", "30")),
    record_fetcher = fetch_record,
)
    isempty(strip(expected_tag)) && throw(ArgumentError("The expected release tag is empty."))
    attempts > 0 || throw(ArgumentError("ZENODO_VERIFY_ATTEMPTS must be positive."))
    delay_seconds >= 0 || throw(ArgumentError("ZENODO_VERIFY_DELAY_SECONDS must be nonnegative."))

    last_failure = "No verification attempt ran."

    for attempt in 1:attempts
        try
            result = check_record(record_fetcher(api_url), expected_tag)
            result.ok && return result
            last_failure = result.message
        catch error
            last_failure = sprint(showerror, error)
        end

        if attempt < attempts
            println(
                stderr,
                "Zenodo verification attempt $attempt/$attempts failed: $last_failure Retrying in $(delay_seconds) seconds.",
            )
            sleep(delay_seconds)
        end
    end

    error("Zenodo release verification failed after $attempts attempts: $last_failure")
end

function main(args)
    length(args) == 1 || throw(ArgumentError("Usage: verify_zenodo_release.jl <release-tag>"))
    result = verify_release(only(args))
    println(result.message)

    return nothing
end

end # module ZenodoReleaseVerification

if abspath(PROGRAM_FILE) == @__FILE__
    try
        ZenodoReleaseVerification.main(ARGS)
    catch error
        println(stderr, "ERROR: ", sprint(showerror, error))
        exit(1)
    end
end

