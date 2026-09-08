# Remote illustrations

REMOTE START

The test replaces the loopback URL placeholders with the invocation-specific endpoint supplied by `Scripts/image_test_controller.py`. This exercises loopback, not arbitrary-host networking.

## Fast plain HTTP image

![Fast remote orange](http://127.0.0.1:PORT/wide.png)

## Slow plain HTTP image

The controller holds this response until the test explicitly releases it after verifying the loading state and readable text below.

![Slow remote green](http://127.0.0.1:PORT/slow.png)

## Unreachable images

![Refused remote](http://127.0.0.1:1/never.png)

![Secure handshake failure](https://127.0.0.1:PORT/wide.png)

![Not an image response](http://127.0.0.1:PORT/not-an-image.png)

![Not found response](http://127.0.0.1:PORT/absent.png)

REMOTE END
