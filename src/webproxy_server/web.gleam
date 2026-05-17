import gleam/bytes_tree
import gleam/http/response
import mist

const not_found_status_code = 404

pub fn not_found() -> response.Response(mist.ResponseData) {
  response.new(not_found_status_code)
  |> set_body("Not Found")
}

pub fn set_body(
  resp: response.Response(a),
  body: String,
) -> response.Response(mist.ResponseData) {
  response.set_body(resp, mist.Bytes(bytes_tree.from_string(body)))
}
