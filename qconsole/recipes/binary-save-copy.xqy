xquery version "1.0-ml";

declare variable $URI := '/foo.xml';
declare variable $NEW_NAME := $URI || '.bin'

xdmp:document-insert(
  $NEW_NAME,
  binary{ doc($uri)
    => xdmp:quote()
    => xdmp:base64-encode()
    => xs:base64Binary()
    => xs:hexBinary()
  }
)
