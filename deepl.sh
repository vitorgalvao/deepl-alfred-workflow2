#!/bin/bash

set -o errexit -o pipefail -o noclobber -o nounset
PATH="$PATH:/usr/local/bin/"
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  key="$1"
  case "$key" in
  -l | --lang)
    LANGUAGE="$2"
    shift # past argument
    shift # past value
    ;;
  *) # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift              # past argument
    ;;
  esac
done
set -- "${POSITIONAL[@]:-}" # restore positional parameters

if [ -z "$1" ]; then
  echo "SYNTAX : $0 [-l language] <query>" >&2
  echo "Example: $0 -l DE \"This is just an example.\""
  exit 1
fi

if ! type jq >/dev/null 2>&1; then
  if type brew >/dev/null 2>&1; then
      HOMEBREW_NO_AUTO_UPDATE=1 brew install jq >/dev/null || exit 2
    else
      echo "Install 'jq' first." >&2
      exit 2
    fi
fi

query="$(echo "$1" | iconv -f utf-8-mac -t utf-8)"

if [[ $query != *. ]] ; then
  echo '{"items": [{"uid": null,"arg": "End query with a dot","valid": "yes","autocomplete": "autocomplete","title": "End query with a dot"}]}'
  exit 1
fi

query="$(echo $query|sed 's/.$//')"
data='{"jsonrpc":"2.0","method": "LMT_handle_jobs","params":{"jobs":[{"kind":"default","raw_en_sentence":"'"${query}"'","raw_en_context_before":[],"raw_en_context_after":[],"quality":"fast"}],"lang":{"user_preferred_langs":["FR","DE","EN"],"source_lang_user_selected":"auto","target_lang":"'"${LANGUAGE:-EN}"'"},"priority":-1,"timestamp":'$(date +"%s")'},"id":'$(jot -r 1  10000000 99999999)'}}'
contentlen=$(($(echo $data|wc -c)-1))

curl -s 'https://www2.deepl.com/jsonrpc' \
-XPOST \
-H 'Content-Type: text/plain' \
-H 'Accept: */*' \
-H 'Host: www2.deepl.com' \
-H 'Accept-Language: en-us' \
-H 'Accept-Encoding: br, deflate' \
-H 'Origin: https://www.deepl.com' \
-H 'Referer: https://www.deepl.com/translator' \
-H 'Content-Length: '"${contentlen}" \
-H 'DNT: 1' \
-H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0.2 Safari/605.1.15' \
-H 'Connection: keep-alive' \
-H 'Cookie: LMTBID=3667c2c5-8f5e-4f4c-85ba-6cd0e0956407|29c9ca7c29ac9af6a5b4dfcae1e970bc' \
--data-binary "${data}" \
| jq -r '{items: [.result.translations[0].beams[] | {uid: null, arg:.postprocessed_sentence, valid: "yes", autocomplete: "autocomplete",title: .postprocessed_sentence}]}'
