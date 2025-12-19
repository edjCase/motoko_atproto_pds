import ServerInfoHandler "./Handlers/ServerInfoHandler";
import RouteContext "mo:liminal@3/RouteContext";
import Route "mo:liminal@3/Route";
import Text "mo:core@1/Text";
import DID "mo:did@3";

module {

    public class Router(
        serverInfoHandler : ServerInfoHandler.Handler
    ) = this {

        public func getLandingPage(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
            let serverInfo = serverInfoHandler.get();
            let landingPageHtml = "<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>ATProto PDS for DAOs</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Courier New', monospace;
            background: #0a0a0a;
            color: #00ff00;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            line-height: 1.6;
        }
        .terminal {
            background: #000;
            border: 2px solid #00ff00;
            border-radius: 8px;
            box-shadow: 0 0 20px rgba(0, 255, 0, 0.3), inset 0 0 50px rgba(0, 255, 0, 0.05);
            padding: 40px;
            max-width: 800px;
            width: 100%;
        }
        .prompt {
            color: #00ff00;
            margin-bottom: 5px;
        }
        .prompt:before {
            content: \"$ \";
            color: #00ff00;
        }
        h1 {
            font-size: 2rem;
            margin-bottom: 30px;
            color: #00ff00;
            text-shadow: 0 0 10px rgba(0, 255, 0, 0.5);
        }
        .section {
            margin-bottom: 30px;
        }
        .links-section {
            padding-bottom: 20px;
            margin-bottom: 30px;
            border-bottom: 1px dashed #00ff00;
        }
        .section-title {
            color: #00ff00;
            font-weight: bold;
            margin-bottom: 10px;
            text-decoration: underline;
        }
        p {
            margin-bottom: 15px;
            color: #00dd00;
        }
        .highlight {
            color: #00ff00;
            font-weight: bold;
        }
        a {
            color: #00ff00;
            text-decoration: none;
            border-bottom: 1px solid #00ff00;
            transition: all 0.3s;
        }
        a:hover {
            color: #fff;
            border-bottom-color: #fff;
            text-shadow: 0 0 5px rgba(0, 255, 0, 0.8);
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #00ff00;
            font-size: 0.9rem;
            color: #00aa00;
        }
        .blink {
            animation: blink 1s infinite;
        }
        @keyframes blink {
            0%, 50% { opacity: 1; }
            51%, 100% { opacity: 0; }
        }
        .copy-btn {
            background: #000;
            color: #00ff00;
            border: 1px solid #00ff00;
            padding: 2px 8px;
            cursor: pointer;
            font-family: 'Courier New', monospace;
            font-size: 0.8rem;
            margin-left: 8px;
            transition: all 0.2s;
        }
        .copy-btn:hover {
            background: #00ff00;
            color: #000;
        }
        .copy-btn.copied {
            background: #00ff00;
            color: #000;
        }
        @media (max-width: 600px) {
            .terminal {
                padding: 30px 20px;
            }
            h1 {
                font-size: 1.5rem;
            }
        }
    </style>
</head>
<body>
    <div class=\"terminal\">
        <h1>ATProto PDS for DAOs<span class=\"blink\">_</span></h1>

        <div class=\"section links-section\">
            <p class=\"prompt\">Quick Links</p>
            <p>
                Atmosphere: <span id=\"handle-text\">at://{HANDLE}</span><button class=\"copy-btn\" onclick=\"copyToClipboard('at://{HANDLE}', this)\">Copy</button><br>
                BluSky Profile: <a href=\"https://bsky.app/profile/{HANDLE}\" target=\"_blank\">bsky.app/profile/{HANDLE}</a><br>
                DID: <span class=\"highlight\" id=\"did-text\">{PLC_DID}</span><button class=\"copy-btn\" onclick=\"copyToClipboard('{PLC_DID}', this)\">Copy</button> (<a href=\"https://web.plc.directory/did/{PLC_DID}\" target=\"_blank\">Directory</a>)<br>
            </p>
        </div>

        <div class=\"section\">
            <p class=\"section-title\">&gt; What is ATProto?</p>
            <p>
                AT Protocol is a decentralized social networking protocol that lets you own your identity and data.
                A <span class=\"highlight\">Personal Data Server (PDS)</span> hosts your social content, posts, and profile—giving you
                control over your online presence independent of any single platform.
            </p>
        </div>

        <div class=\"section\">
            <p class=\"section-title\">&gt; Why DAOs?</p>
            <p>
                This PDS implementation is designed for <span class=\"highlight\">DAO-controlled accounts</span>.
                Instead of individual ownership, your organization can collectively manage an ATProto presence—posting
                announcements, building reputation, and participating in decentralized social networks through
                on-chain governance.
            </p>
        </div>

        <div class=\"section\">
            <p class=\"section-title\">&gt; Use Cases</p>
            <p>
                → Decentralized brand accounts with collective control<br>
                → Transparent organizational communications<br>
                → DAO-governed social media presence<br>
                → Community-driven content curation
            </p>
        </div>

        <div class=\"section\">
            <div style=\"display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;\">
                <p class=\"section-title\" style=\"margin-bottom: 0;\">&gt; Latest Bluesky Posts</p>
                <button onclick=\"loadPosts()\" style=\"background: #000; color: #00ff00; border: 1px solid #00ff00; padding: 5px 10px; cursor: pointer; font-family: 'Courier New', monospace;\">Refresh</button>
            </div>
            <div id=\"posts-container\" style=\"margin-top: 15px; min-height: 50px;\">
                <p style=\"color: #00aa00;\">Loading posts...</p>
            </div>
        </div>

        <div class=\"section\">
            <div style=\"display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;\">
                <p class=\"section-title\" style=\"margin-bottom: 0;\">&gt; Relay Status</p>
                <button onclick=\"checkRelayStatus()\" style=\"background: #000; color: #00ff00; border: 1px solid #00ff00; padding: 5px 10px; cursor: pointer; font-family: 'Courier New', monospace;\">Check</button>
            </div>
            <div style=\"margin-bottom: 10px;\">
                <label style=\"color: #00ff00; display: block; margin-bottom: 5px;\">Relay URL:</label>
                <input type=\"text\" id=\"relay-url\" value=\"https://bsky.network\" style=\"background: #000; color: #00ff00; border: 1px solid #00ff00; padding: 8px; font-family: 'Courier New', monospace; width: 100%; max-width: 400px;\">
            </div>
            <div id=\"relay-status\" style=\"min-height: 20px; margin-top: 15px;\"></div>
        </div>

        <div class=\"section\" id=\"crawl-section\" style=\"display: none;\">
            <p class=\"section-title\">&gt; Request Crawl</p>
            <p style=\"color: #00aa00; margin-bottom: 15px;\">Request that a relay crawl this PDS to index it.</p>
            <button onclick=\"requestCrawl()\" style=\"background: #000; color: #00ff00; border: 1px solid #00ff00; padding: 8px 15px; cursor: pointer; font-family: 'Courier New', monospace; margin-bottom: 15px;\">Request Crawl</button>
            <div id=\"crawl-message\" style=\"min-height: 20px;\"></div>
        </div>

        <div class=\"footer\">
            <p class=\"prompt\">Open source implementation in Motoko</p>
            <p><a href=\"https://github.com/edjCase/motoko_atproto\" target=\"_blank\">github.com/edjCase/motoko_atproto</a></p>
        </div>
    </div>

    <script>
        async function checkRelayStatus() {
            const statusDiv = document.getElementById('relay-status');
            const crawlSection = document.getElementById('crawl-section');
            const relay = document.getElementById('relay-url').value;
            const handle = '{HANDLE}';

            statusDiv.innerHTML = '<p style=\"color: #00aa00;\">$ Checking relay status...</p>';

            let output = '<div style=\"font-family: \\'Courier New\\', monospace; color: #00dd00;\">';
            output += '<p style=\"color: #00ff00;\">$ relay-status-check --relay=' + relay + ' --handle=' + handle + '</p>';

            let isIndexed = false;

            try {
                // Test 1: Resolve Handle
                const resolveRes = await fetch(relay + '/xrpc/com.atproto.identity.resolveHandle?handle=' + handle);
                const resolveOk = resolveRes.ok;
                output += '<p>[1/3] resolveHandle: ' + (resolveOk ? '<span style=\"color: #00ff00;\">✓ FOUND</span>' : '<span style=\"color: #ff6600;\">✗ NOT FOUND</span>') + '</p>';

                // Test 2: Get Profile
                const profileRes = await fetch(relay + '/xrpc/app.bsky.actor.getProfile?actor=' + handle);
                const profileOk = profileRes.ok;
                output += '<p>[2/3] getProfile: ' + (profileOk ? '<span style=\"color: #00ff00;\">✓ FOUND</span>' : '<span style=\"color: #ff6600;\">✗ NOT FOUND</span>') + '</p>';

                // Test 3: Get Feed
                const feedRes = await fetch(relay + '/xrpc/app.bsky.feed.getAuthorFeed?actor=' + handle + '&limit=1');
                const feedOk = feedRes.ok;
                output += '<p>[3/3] getAuthorFeed: ' + (feedOk ? '<span style=\"color: #00ff00;\">✓ FOUND</span>' : '<span style=\"color: #ff6600;\">✗ NOT FOUND</span>') + '</p>';

                isIndexed = resolveOk || profileOk || feedOk;

                output += '<p style=\"margin-top: 10px; color: #00ff00;\">---</p>';
                if (isIndexed) {
                    output += '<p style=\"color: #00ff00;\">✓ Status: INDEXED</p>';
                    crawlSection.style.display = 'none';
                } else {
                    output += '<p style=\"color: #ff6600;\">✗ Status: NOT INDEXED</p>';
                    output += '<p style=\"color: #00aa00;\">→ Crawl request needed</p>';
                    crawlSection.style.display = 'block';
                }
            } catch (error) {
                output += '<p style=\"color: #ff0000;\">ERROR: ' + error.message + '</p>';
                crawlSection.style.display = 'block';
            }

            output += '</div>';
            statusDiv.innerHTML = output;
        }

        async function requestCrawl() {
            const messageDiv = document.getElementById('crawl-message');
            const hostname = '{FULL_DOMAIN}';
            const relay = document.getElementById('relay-url').value;

            messageDiv.innerHTML = '<p style=\"color: #00aa00;\">$ Requesting crawl...</p>';

            try {
                const response = await fetch(relay + '/xrpc/com.atproto.sync.requestCrawl', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ hostname: hostname })
                });

                if (response.ok) {
                    messageDiv.innerHTML = '<p style=\"color: #00ff00;\">✓ Crawl request successful</p>';
                    setTimeout(checkRelayStatus, 2000);
                } else {
                    const errorText = await response.text();
                    messageDiv.innerHTML = '<p style=\"color: #ff0000;\">✗ Crawl request failed (HTTP ' + response.status + '): ' + errorText + '</p>';
                }
            } catch (error) {
                messageDiv.innerHTML = '<p style=\"color: #ff0000;\">✗ Error: ' + error.message + '</p>';
            }
        }

        async function loadPosts() {
            const container = document.getElementById('posts-container');

            try {
                const response = await fetch('/xrpc/com.atproto.repo.listRecords?repo={PLC_DID}&collection=app.bsky.feed.post&limit=10&reverse=true');
                const data = await response.json();

                if (!data.records || data.records.length === 0) {
                    container.innerHTML = '<p style=\"color: #00aa00;\">No posts yet.</p>';
                    return;
                }

                let html = '';
                data.records.forEach((record, index) => {
                    const text = record.value.text || '';
                    const date = new Date(record.value.createdAt).toLocaleString();
                    html += `
                        <div style=\"margin-bottom: 20px; padding: 15px; border: 1px solid #003300; background: rgba(0, 255, 0, 0.02);\">
                            <p style=\"color: #00dd00; white-space: pre-wrap; margin-bottom: 10px;\">${text}</p>
                            <p style=\"color: #00aa00; font-size: 0.85rem;\">${date}</p>
                        </div>
                    `;
                });

                container.innerHTML = html;
            } catch (error) {
                container.innerHTML = '<p style=\"color: #ff0000;\">Error loading posts: ' + error.message + '</p>';
            }
        }

        function copyToClipboard(text, button) {
            navigator.clipboard.writeText(text).then(function() {
                const originalText = button.textContent;
                button.textContent = '\\u2713';
                button.classList.add('copied');
                setTimeout(function() {
                    button.textContent = originalText;
                    button.classList.remove('copied');
                }, 2000);
            }).catch(function(err) {
                console.error('Failed to copy: ', err);
            });
        }

        // Load posts on page load
        loadPosts();
    </script>
</body>
</html>"
            |> Text.replace(_, #text("{HANDLE}"), serverInfo.hostname)
            |> Text.replace(
                _,
                #text("{FULL_DOMAIN}"),
                switch (serverInfo.serviceSubdomain) {
                    case (?subdomain) subdomain # "." # serverInfo.hostname;
                    case (null) serverInfo.hostname;
                },
            )
            |> Text.replace(_, #text("{PLC_DID}"), DID.Plc.toText(serverInfo.plcIdentifier));

            routeContext.buildResponse(#ok, #html(landingPageHtml));
        };
    };
};
