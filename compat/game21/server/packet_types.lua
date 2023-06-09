local t = {}
t.client_to_server = {
    "encrypted_msg",
    "heartbeat",
    "disconnect",
    "public_key",
    "register",
    "login",
    "logout",
    "delete_account",
    "request_top_scores",
    "replay",
    "request_own_score",
    "request_top_scores_and_own_score",
    "started_game",
    "compressed_replay",
    "request_server_status",
    "ready",
}
t.server_to_client = {
    "encrypted_msg",
    "kick",
    "public_key",
    "registration_success",
    "registration_failure",
    "login_success",
    "login_failure",
    "logout_success",
    "logout_failure",
    "delete_account_success",
    "delete_account_failure",
    "top_scores",
    "own_score",
    "top_scores_and_own_score",
    "server_status",
}
return t
