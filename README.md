# Slirc: IRC interface to Slack

If you need to communicate with other people via Slack, but would prefer to
avoid the web interface and Electron application, they offer an IRC gateway.
Unfortunately, the gateway has some shortcomings that make it a fairly
unsatisfactory solution:

* The away status of other users is not shown in /WHOIS queries.
* Channels that you are a member of (as shown in the web interface) are not joined automatically, and if you don't join them explicitly, you won't see messages from them. Other users who are trying to talk to you may not expect this.
* Pasting is cumbersome: the normal way that web interface users will paste text snippets leads to you receiving a message containing only a URL directing you to the Slack web interface in order to view the pasted text.
* If you have email notifications enabled, they will continue to come through while you're connected, and will stack up endlessly, even if you are not marked as away. This is because messages are not marked as read until you disconnect the IRC client. The rationale given for this is that they have no way of knowing if you've actually seen the message in the IRC client (but then why mark them as read once when the client disconnects?).
* The IRC gateway is not available for all users.

I ended up implementing my own gateway in the form of a locally-running Perl
script that communicates with Slack's RTM interface. This has numerous
advantages over the official interface:

* Away status is reported correctly in /WHOIS and /WHO queries.
* Channels that you're in are force-joined on connection. If you leave a channel in IRC, you leave it via the API too (making the change visible to other users).
* Pasted text snippets are fetched and displayed inline as ordinary messages.
* Messages are marked as read on receipt in the normal way.
* It doesn't require any intervention on the part of the workspace owner to use. It requires a Slack API key, but you can obtain a usable key on your own, in spite of what the Slack documentation claims.
* Being a self-contained script, it's easy to customize if you don't like the way it works.

### Installation and setup

To run it, you will first need to install the prerequisite modules from CPAN.
These are:

* `AnyEvent`
* `AnyEvent::HTTP`
* `AnyEvent::Socket`
* `AnyEvent::WebSocket::Client`
* `URI::Encode`
* `Data::Dumper`
* `JSON`

On most Linux systems, you will be able to install each of these with:

```
sudo cpan <module-list>
```

Make sure you have OpenSSL development headers installed before attempting to
install the socket module.

You then need to create a configuration file. This should contain the following
lines:

```
slack_token=<API key>
password=<Password for IRC server>
port=<Port for IRC server>
```

Save your configuration file and run the gateway with:

```
./slirc.pl <file.conf>
```

You should then be able to connect using the IRC client of your choice on the
configured port using the password specified in the configuration file. The IRC
server does not support TLS, and so doesn't bind to any address other than
127.0.0.1. If you need access to it across the network, you should use a TLS
proxy or a TLS-capable IRC bouncer on the same host.

### Obtaining an API key

You can obtain a "legacy" API key by requesting it via the web interface from
your workspace owner. However, you can also obtain one yourself, since the web
interface uses the RTM API.

To do this, log in via the web interface with your web browser's network
request tracing enabled and wait. Eventually, the chat interface will be ready,
and you should see a series of requests to the API. Pick any of them and look
in the POST body for a parameter called token. As long as you don't explicitly
log out (clearing cookies is fine), this key will remain usable.

A simple Perl script using LWP::UserAgent automates the process of extracting
API keys from non-SSO login credentials:

```
./slack_login_key.pl
```

### Using the gateway

Multiple IRC clients can be connected simultaneously. Messages from any client
will be sent via the Slack API. Messages and other events received from the
Slack API will be broadcast to all connected IRC clients.

If the RTM connection goes down, all IRC clients will be disconnected and will
need to reconnect. IRC clients that connect before the RTM connection is
available will not be sent welcome messages until the connection is up.

A ChanServ-like user called X is present on the server. It supports the
following commands:

```
/msg X newgroup <name>
    Create a new private group. Users can be invited to the group via the usual /INVITE command.
/msg X newchan <name>
    Create a new public channel.
/msg X archive <name>
    Archive the given group or channel.
/msg X cat <file-id>
    Fetch the given file and display it inline in the form of NOTICE messages.
/msg X disconnect
    Disconnect and reconnect the RTM client.
```

Mentions of the form `<@nickname>` or `<#channel>` will be translated and appear
correctly to clients using the web interface.

### Copyright

Copyright (C) 2017-2019 Daniel Beer <dlbeer@gmail.com>

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.
