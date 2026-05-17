import database
import envoy
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/http/request
import gleam/httpc
import gleam/json

pub type User {
  User(
    id: String,
    display_name: String,
    scopes: List(String),
    organization_id: String,
  )
}

fn json_to_user_decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.string)
  use display_name <- decode.field("displayName", decode.string)
  use scopes <- decode.field("scopes", decode.list(decode.string))
  use organization_id <- decode.field("organization_id", decode.string)
  decode.success(User(id:, display_name:, scopes:, organization_id:))
}

pub fn new_user_table() -> database.Table(User) {
  atom.create("users_table")
  |> database.create_ets_table
}

pub fn get_user_by_auth_token(
  cache: database.Table(User),
  token: String,
) -> Result(User, Nil) {
  let query_result = {
    use ref <- database.transaction(cache)
    database.find(ref, token)
  }
  case query_result {
    Ok(user) -> Ok(user)
    Error(_) -> {
      let assert Ok(base_req) = request.to(get_authentication_url())
      let req =
        request.prepend_header(base_req, "accept", "application/json")
        |> request.prepend_header("authorization", token)

      case httpc.send(req) {
        Ok(resp) if resp.status == 200 -> {
          case json.parse(resp.body, json_to_user_decoder()) {
            Error(_) -> Error(Nil)
            Ok(user) -> {
              let _ = {
                use ref <- database.transaction(cache)
                database.upsert(ref, token, user)
              }
              Ok(user)
            }
          }
        }
        _ -> Error(Nil)
      }
    }
  }
}

fn get_authentication_url() {
  let assert Ok("https://" <> url) = envoy.get("AUTHENTICATION_URL") as "Please, inform a valid AUTHENTICATION_URL environment variable according to the documentation."

  "https://" <> url
}
