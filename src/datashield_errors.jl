"""
    datashield_errors()

Retrieve and display an information message about the last errors occurred in a
DataSHIELD session, once per session.

# Returns
- nothing if no errors are found, otherwise the errors for each server
"""
function datashield_errors()
    _inform_once(_new_errors_message(), "error_id")
    if haskey(_STATE, _LAST_ERRORS_KEY)
        return _STATE[_LAST_ERRORS_KEY]
    else
        return nothing
    end
end

"""
    datashield_error_messages()

Retrieve the last errors occurred in a DataSHIELD session and format them with
a cross prefix for each server.

# Returns
- nothing if no errors are found, otherwise the formatted error messages
"""
function datashield_error_messages()
    if haskey(_STATE, _LAST_ERRORS_KEY)
        errors = _STATE[_LAST_ERRORS_KEY]
        msgs = _format_errors(_remove_curly_brackets(errors))
        return ["× $msg" for msg in msgs]
    else
        return nothing
    end
end
