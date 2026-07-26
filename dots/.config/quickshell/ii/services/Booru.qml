pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.services
import Quickshell;
import QtQuick;

/**
 * A service for interacting with various booru APIs.
 */
Singleton {
    id: root
    property Component booruResponseDataComponent: BooruResponseData {}

    signal tagSuggestion(string query, var suggestions)
    signal responseFinished()

    property string failMessage: Translation.tr("That didn't work. Tips:\n- Check your tags and NSFW settings\n- If you don't have a tag in mind, type a page number")
    property var responses: []
    property int runningRequests: 0
    property var defaultUserAgent: Config.options?.networking?.userAgent || "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
    property var providerList: Object.keys(providers).filter(provider => provider !== "system" && providers[provider].api)
    property var providers: {
        "system": { "name": Translation.tr("System") },
        "yandere": {
            "name": "yande.re",
            "url": "https://yande.re",
            "api": "https://yande.re/post.json",
            "description": Translation.tr("All-rounder | Good quality, decent quantity"),
            "mapFunc": (response) => {
                return response.map(item => {
                    return {
                        "id": item.id,
                        "width": item.width,
                        "height": item.height,
                        "aspect_ratio": item.width / item.height,
                        "tags": item.tags,
                        "rating": item.rating,
                        "is_nsfw": (item.rating != 's'),
                        "md5": item.md5,
                        "preview_url": item.preview_url,
                        "sample_url": item.sample_url ?? item.file_url,
                        "file_url": item.file_url,
                        "file_ext": item.file_ext,
                        "source": getWorkingImageSource(item.source) ?? item.file_url,
                    }
                })
            },
            "tagSearchTemplate": "https://yande.re/tag.json?order=count&limit=10&name={{query}}*",
            "tagMapFunc": (response) => {
                return response.map(item => {
                    return {
                        "name": item.name,
                        "count": item.count
                    }
                })
            }
        },
        "konachan": {
            "name": "Konachan",
            "url": "https://konachan.net",
            "api": "https://konachan.net/post.json",
            "description": Translation.tr("For desktop wallpapers | Good quality"),
            "mapFunc": (response) => {
                return response.map(item => {
                    return {
                        "id": item.id,
                        "width": item.width,
                        "height": item.height,
                        "aspect_ratio": item.width / item.height,
                        "tags": item.tags,
                        "rating": item.rating,
                        "is_nsfw": (item.rating != 's'),
                        "md5": item.md5,
                        "preview_url": item.preview_url,
                        "sample_url": item.sample_url ?? item.file_url,
                        "file_url": item.file_url,
                        "file_ext": item.file_ext,
                        "source": getWorkingImageSource(item.source) ?? item.file_url,
                    }
                })
            },
            "tagSearchTemplate": "https://konachan.net/tag.json?order=count&limit=10&name={{query}}*",
            "tagMapFunc": (response) => {
                return response.map(item => {
                    return {
                        "name": item.name,
                        "count": item.count
                    }
                })
            }
        },
        "zerochan": {
            "name": "Zerochan",
            "url": "https://www.zerochan.net",
            "api": "https://www.zerochan.net/?json",
            "description": Translation.tr("Clean stuff | Excellent quality, no NSFW"),
            "mapFunc": (response) => {
                response = response.items
                return response.map(item => {
                    return {
                        "id": item.id,
                        "width": item.width,
                        "height": item.height,
                        "aspect_ratio": item.width / item.height,
                        "tags": item.tags.join(" "),
                        "rating": "safe", // Zerochan doesn't have nsfw
                        "is_nsfw": false,
                        "md5": item.md5,
                        "preview_url": item.thumbnail,
                        "sample_url": item.thumbnail,
                        "file_url": item.thumbnail,
                        "file_ext": "avif",
                        "source": getWorkingImageSource(item.source) ?? item.thumbnail,
                        "character": item.tag
                    }
                })
            }
        },
        "danbooru": {
            "name": "Danbooru",
            "url": "https://danbooru.donmai.us",
            "api": "https://danbooru.donmai.us/posts.json",
            "description": Translation.tr("The popular one | Best quantity, but quality can vary wildly"),
            "mapFunc": (response) => {
                return response.map(item => {
                    return {
                        "id": item.id,
                        "width": item.image_width,
                        "height": item.image_height,
                        "aspect_ratio": item.image_width / item.image_height,
                        "tags": item.tag_string,
                        "rating": item.rating,
                        "is_nsfw": (item.rating != 's'),
                        "md5": item.md5,
                        "preview_url": item.preview_file_url,
                        "sample_url": item.file_url ?? item.large_file_url,
                        "file_url": item.large_file_url,
                        "file_ext": item.file_ext,
                        "source": getWorkingImageSource(item.source) ?? item.file_url,
                    }
                })
            },
            "tagSearchTemplate": "https://danbooru.donmai.us/tags.json?limit=10&search[name_matches]={{query}}*",
            "tagMapFunc": (response) => {
                return response.map(item => {
                    return {
                        "name": item.name,
                        "count": item.post_count
                    }
                })
            }
        },
        "gelbooru": {
            "name": "Gelbooru",
            "url": "https://gelbooru.com",
            "api": "https://gelbooru.com/index.php?page=dapi&s=post&q=index&json=1",
            "description": Translation.tr("The hentai one | Great quantity, a lot of NSFW, quality varies wildly"),
            "mapFunc": (response) => {
                response = response.post
                return response.map(item => {
                    return {
                        "id": item.id,
                        "width": item.width,
                        "height": item.height,
                        "aspect_ratio": item.width / item.height,
                        "tags": item.tags,
                        "rating": item.rating.replace('general', 's').charAt(0),
                        "is_nsfw": (item.rating != 's'),
                        "md5": item.md5,
                        "preview_url": item.preview_url,
                        "sample_url": item.sample_url ?? item.file_url,
                        "file_url": item.file_url,
                        "file_ext": item.file_url.split('.').pop(),
                        "source": getWorkingImageSource(item.source) ?? item.file_url,
                    }
                })
            },
            "tagSearchTemplate": "https://gelbooru.com/index.php?page=dapi&s=tag&q=index&json=1&orderby=count&limit=10&name_pattern={{query}}%",
            "tagMapFunc": (response) => {
                return response.tag.map(item => {
                    return {
                        "name": item.name,
                        "count": item.count
                    }
                })
            }
        },
        "e621": {
            "name": "e621",
            "url": "https://e621.net",
            "api": "https://e621.net/posts.json",
            "description": Translation.tr("Furry | Adult by default"),
            "mapFunc": (response) => {
                return response.posts.map(item => {
                    const allTags = [].concat(
                        item.tags.general ?? [],
                        item.tags.species ?? [],
                        item.tags.character ?? [],
                        item.tags.copyright ?? [],
                        item.tags.artist ?? [],
                        item.tags.meta ?? []
                    ).join(" ")
                    const file = item.file ?? {}
                    const preview = item.preview ?? {}
                    const sample = item.sample ?? {}
                    return {
                        "id": item.id,
                        "width": file.width ?? 0,
                        "height": file.height ?? 0,
                        "aspect_ratio": (file.width && file.height) ? (file.width / file.height) : 1,
                        "tags": allTags,
                        "rating": item.rating,
                        "is_nsfw": (item.rating !== 's'),
                        "md5": file.md5 ?? "",
                        "preview_url": preview.url ?? file.url,
                        "sample_url": (sample.has ? sample.url : null) ?? file.url,
                        "file_url": file.url,
                        "file_ext": file.ext,
                        "source": getWorkingImageSource(item.sources?.[0] ?? "") || file.url,
                        "score": item.score?.total ?? 0,
                        "fav_count": item.fav_count ?? 0,
                        "is_favorited": item.is_favorited ?? false,
                    }
                })
            },
            "tagSearchTemplate": "https://e621.net/tags.json?search[name_matches]={{query}}*&search[order]=count&limit=10",
            "tagMapFunc": (response) => {
                return response.map(item => {
                    return {
                        "name": item.name,
                        "count": item.post_count
                    }
                })
            }
        },
        "waifu.im": {
            "name": "waifu.im",
            "url": "https://waifu.im",
            "api": "https://api.waifu.im/images",
            "description": Translation.tr("Waifus only | Excellent quality, limited quantity"),
            "mapFunc": (response) => {
                response = response.items
                return response.map(item => {
                    return {
                        "id": item.id,
                        "width": item.width,
                        "height": item.height,
                        "aspect_ratio": item.width / item.height,
                        "tags": item.tags.map(tag => {return tag.name}).join(" "),
                        "rating": item.isNsfw ? "e" : "s",
                        "is_nsfw": item.isNsfw,
                        "md5": item.md5,
                        "preview_url": item.sample_url ?? item.url, // preview_url just says access denied (maybe i fucked up and sent too many requests idk)
                        "sample_url": item.url,
                        "file_url": item.url,
                        "file_ext": item.extension,
                        "source": getWorkingImageSource(item.source) ?? item.url,
                    }
                })
            },
            "tagSearchTemplate": "https://api.waifu.im/tags?Name={{query}}",
            "tagMapFunc": (response) => {
                return response.items.map(item => {return {"name": item.name}})
            }
        },
        "t.alcy.cc": {
            "name": "Alcy",
            "url": "https://t.alcy.cc",
            "api": "https://t.alcy.cc/",
            "description": Translation.tr("Large images | God tier quality, no NSFW."),
            "fixedTags": [
                {
                    "name": "ycy",
                    "count": "General"
                },
                {
                    "name": "moez",
                    "count": "Moe"
                },
                {
                    "name": "ysz",
                    "count": "Genshin Impact"
                },
                {
                    "name": "fj",
                    "count": "Landscape"
                },
                {
                    "name": "bd",
                    "count": "Girl on white background"
                },
                {
                    "name": "xhl",
                    "count": "Shiggy"
                },
            ],
            "manualParseFunc": (responseText) => {
                // Alcy just returns image links, each on a new line
                const lines = responseText.trim().split('\n');
                return lines.map(line => {
                    return {
                        "id": Qt.md5(line),
                        // Alcy doesn't provide dimensions and images are often of god resolution
                        "width": 1000,
                        "height": 1000,
                        "aspect_ratio": 1,
                        "tags": "[no tags]",
                        "rating": "s",
                        "is_nsfw": false,
                        "md5": Qt.md5(line),
                        "preview_url": line,
                        "sample_url": line,
                        "file_url": line,
                        "file_ext": line.split('.').pop(),
                        "source": "",
                    }
                });
            },
        }
    }
    property var currentProvider: Persistent.states.booru.provider

    // ------------------------------------------------------------------- e621
    // e621 wants two things the other providers don't: a project-identifying
    // User-Agent (https://e621.net/help/api#user-agents) and HTTP Basic auth for
    // anything account-scoped (favourites, votes, the account blacklist).
    readonly property string e621Username: {
        const name = Config.options?.sidebar?.booru?.e621?.username ?? ""
        return (name && name !== "[unset]") ? name : ""
    }
    readonly property string e621ApiKey: KeyringStorage.keyringData?.apiKeys?.e621 ?? ""
    readonly property bool e621Authed: e621Username.length > 0 && e621ApiKey.length > 0
    readonly property string e621UserAgent: `illogical-impulse-sidebar/1.0 (by ${e621Username || "anonymous"} on e621)`
    // e621 answers 422 "You cannot search for more than 40 tags at a time" beyond
    // this, whether or not you are logged in.
    readonly property int e621MaxQueryTags: 40

    function setE621Headers(xhr) {
        xhr.setRequestHeader("User-Agent", root.e621UserAgent)
        if (root.e621Authed)
            xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(`${root.e621Username}:${root.e621ApiKey}`))
    }

    // Blacklisting happens in the *query*: e621 applies its own blacklist in its
    // front-end rather than the API, but the API does understand negation, so we
    // hand the rules to the server instead of filtering afterwards. That keeps a page
    // of `limit` results a page of `limit` usable results, and gets wildcards and
    // metatags (`-young*`, `-rating:e`) for free.
    property var e621AccountRules: []
    readonly property var e621Negations: {
        const rules = (Config.options?.sidebar?.booru?.e621?.blacklist ?? "").split("\n")
            .concat(root.e621AccountRules)
        const terms = []
        const skipped = []
        for (const line of rules) {
            const rule = line.trim()
            if (rule.length === 0 || rule.startsWith("#")) continue
            // A rule listing several tags means "hide posts matching all of them",
            // which no single negation expresses; same for the `-` and `~` operators,
            // which are only meaningful inside such a rule. Report, don't ignore.
            if (/\s/.test(rule) || rule.startsWith("-") || rule.startsWith("~")) skipped.push(rule)
            else if (!terms.includes(`-${rule}`)) terms.push(`-${rule}`)
        }
        if (skipped.length > 0)
            console.log(`[Booru/e621] ${skipped.length} blacklist rule(s) can't be expressed as a search and were not applied:`, skipped.join(" | "))
        return terms
    }

    // Negations count against the tag ceiling, so a long blacklist can crowd out the
    // tags actually being searched for. Say so rather than quietly filtering less.
    property int e621ReportedTruncation: 0
    function e621QueryNegations(tagCount) {
        if (!(Config.options?.sidebar?.booru?.e621?.applyBlacklist ?? true)) return []
        const applied = root.e621Negations.slice(0, Math.max(0, root.e621MaxQueryTags - tagCount))
        const dropped = root.e621Negations.length - applied.length
        if (dropped > 0 && dropped !== root.e621ReportedTruncation) {
            root.e621ReportedTruncation = dropped
            root.addSystemMessage(Translation.tr("%1 blacklist rule(s) left out — e621 allows %2 tags per search. Shorten the blacklist or search fewer tags.")
                .arg(dropped).arg(root.e621MaxQueryTags))
        }
        return applied
    }

    function refreshE621AccountBlacklist() {
        if (!root.e621Authed) {
            root.e621AccountRules = []
            return
        }
        const xhr = new XMLHttpRequest()
        xhr.open("GET", `https://e621.net/users/${encodeURIComponent(root.e621Username)}.json`)
        root.setE621Headers(xhr)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) {
                console.log("[Booru/e621] Could not read the account blacklist:", xhr.status)
                return
            }
            try {
                root.e621AccountRules = (JSON.parse(xhr.responseText).blacklisted_tags ?? "").split("\n")
            } catch (e) {
                console.log("[Booru/e621] Could not parse the account blacklist:", e)
            }
        }
        xhr.send()
    }
    // Credentials arrive late (the keyring loads asynchronously) and can change from
    // either the settings page or the chat commands.
    onE621AuthedChanged: root.refreshE621AccountBlacklist()
    onE621UsernameChanged: root.refreshE621AccountBlacklist()

    function sendE621Request(method, path, body, onOk) {
        if (!root.e621Authed) {
            root.addSystemMessage(Translation.tr("e621: set your username and API key in Settings → Services first"))
            return
        }
        const xhr = new XMLHttpRequest()
        xhr.open(method, `https://e621.net${path}`)
        root.setE621Headers(xhr)
        if (body) xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status >= 200 && xhr.status < 300) {
                if (onOk) onOk()
            } else {
                root.addSystemMessage(Translation.tr("e621: request failed (%1)").arg(xhr.status))
            }
        }
        xhr.send(body ?? null)
    }

    function e621SetFavorite(postId, favorited, onOk) {
        const done = () => {
            root.addSystemMessage(favorited ? Translation.tr("Added to favorites") : Translation.tr("Removed from favorites"))
            if (onOk) onOk()
        }
        if (favorited) root.sendE621Request("POST", "/favorites.json", `post_id=${postId}`, done)
        else root.sendE621Request("DELETE", `/favorites/${postId}.json`, null, done)
    }

    function e621Vote(postId, score) {
        root.sendE621Request("POST", `/posts/${postId}/votes.json`, `score=${score}&no_unvote=true`,
            () => root.addSystemMessage(score > 0 ? Translation.tr("Upvoted") : Translation.tr("Downvoted")))
    }

    function getWorkingImageSource(url) {
        if (url?.includes('pximg.net')) {
            return `https://www.pixiv.net/en/artworks/${url.substring(url.lastIndexOf('/') + 1).replace(/_p\d+\.(png|jpg|jpeg|gif)$/, '')}`;
        }
        return url;
    }
    
    function setProvider(provider) {
        provider = provider.toLowerCase()
        if (providerList.indexOf(provider) !== -1) {
            Persistent.states.booru.provider = provider
            root.addSystemMessage(Translation.tr("Provider set to ") + providers[provider].name
                + (provider == "zerochan" ? Translation.tr(". Notes for Zerochan:\n- You must enter a color\n- Set your zerochan username in `sidebar.booru.zerochan.username` config option. You [might be banned for not doing so](https://www.zerochan.net/api#:~:text=The%20request%20may%20still%20be%20completed%20successfully%20without%20this%20custom%20header%2C%20but%20your%20project%20may%20be%20banned%20for%20being%20anonymous.)!") : ""))
        } else {
            root.addSystemMessage(Translation.tr("Invalid API provider. Supported: \n- ") + providerList.join("\n- "))
        }
    }

    function clearResponses() {
        responses = []
    }

    function addSystemMessage(message) {
        responses = [...responses, root.booruResponseDataComponent.createObject(null, {
            "provider": "system",
            "tags": [],
            "page": -1,
            "images": [],
            "message": `${message}`
        })]
    }

    function constructRequestUrl(tags, nsfw=true, limit=20, page=1) {
        var provider = providers[currentProvider]
        var baseUrl = provider.api
        var url = baseUrl
        var tagString = tags.join(" ")
        if (!nsfw && !(["zerochan", "waifu.im", "t.alcy.cc"].includes(currentProvider))) {
            if (currentProvider == "gelbooru")
                tagString += " rating:general";
            else if (currentProvider == "e621")
                tagString += " rating:s"; // e621 uses short rating codes (s/q/e)
            else
                tagString += " rating:safe";
        }
        if (currentProvider === "e621") {
            const negations = root.e621QueryNegations(tagString.split(" ").filter(t => t.length > 0).length)
            if (negations.length > 0) tagString += " " + negations.join(" ")
        }
        var params = []
        // Tags & limit
        if (currentProvider === "zerochan") {
            params.push("c=" + tagString) // zerochan doesn't have search in api, so we use color
            params.push("l=" + limit)
            params.push("s=" + "fav")
            params.push("t=" + 1)
            params.push("p=" + page)
        }
        else if (currentProvider === "waifu.im") {
            var tagsArray = tagString.split(" ");
            tagsArray.forEach(tag => {
                params.push("IncludedTags=" + encodeURIComponent(tag.toLowerCase()));
            });
            params.push("PageSize=" + Math.min(limit, 30)) // Only admin can do > 30
            params.push("IsNsfw=" + (nsfw ? "All" : "False")) // null is random
        }
        else if (currentProvider === "t.alcy.cc") {
            url += tagString
            params.push("json")
            params.push("quantity=" + limit)
        }
        else {
            params.push("tags=" + encodeURIComponent(tagString))
            params.push("limit=" + limit)
            if (currentProvider == "gelbooru") {
                params.push("pid=" + page)
            }
            else {
                params.push("page=" + page)
            }
        }
        if (baseUrl.indexOf("?") === -1) {
            url += "?" + params.join("&")
        } else {
            url += "&" + params.join("&")
        }
        return url
    }

    function makeRequest(tags, nsfw=false, limit=20, page=1) {
        var url = constructRequestUrl(tags, nsfw, limit, page)
        console.log("[Booru] Making request to " + url)

        const newResponse = root.booruResponseDataComponent.createObject(null, {
            "provider": currentProvider,
            "tags": tags,
            "page": page,
            "images": [],
            "message": ""
        })

        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    // console.log("[Booru] Raw response: " + xhr.responseText)
                    const provider = providers[currentProvider]
                    let response;
                    if (provider.manualParseFunc) {
                        response = provider.manualParseFunc(xhr.responseText)
                    } else {
                        response = JSON.parse(xhr.responseText)
                        response = provider.mapFunc(response)
                    }
                    // console.log("[Booru] Mapped response: " + JSON.stringify(response))
                    newResponse.images = response
                    newResponse.message = response.length > 0 ? "" : root.failMessage
                    
                } catch (e) {
                    console.log("[Booru] Failed to parse response: " + e)
                    newResponse.message = root.failMessage
                } finally {
                    root.runningRequests--;
                    root.responses = [...root.responses, newResponse]
                }
            }
            else if (xhr.readyState === XMLHttpRequest.DONE) {
                console.log("[Booru] Request failed with status: " + xhr.status)
                newResponse.message = root.failMessage
                root.runningRequests--;
                root.responses = [...root.responses, newResponse]
            }
            root.responseFinished()
        }

        try {
            // Required for danbooru and konachan
            if (["danbooru", "konachan"].includes(currentProvider)) {
                xhr.setRequestHeader("User-Agent", defaultUserAgent)
            }
            else if (currentProvider == "zerochan") {
                const userAgent = Config.options?.sidebar?.booru?.zerochan?.username ? `Desktop sidebar booru viewer - username: ${Config.options.sidebar.booru.zerochan.username}` : defaultUserAgent
                xhr.setRequestHeader("User-Agent", userAgent)
            }
            else if (currentProvider == "e621") {
                root.setE621Headers(xhr)
            }
            root.runningRequests++;
            xhr.send()
        } catch (error) {
            console.log("Could not set User-Agent:", error)
        }
    }

    property var currentTagRequest: null
    function triggerTagSearch(query) {
        if (currentTagRequest) {
            currentTagRequest.abort();
        }

        var provider = providers[currentProvider]
        if (provider.fixedTags) {
            root.tagSuggestion(query, provider.fixedTags)
            return provider.fixedTags;
        } else if (!provider.tagSearchTemplate) {
            return
        }
        var url = provider.tagSearchTemplate.replace("{{query}}", encodeURIComponent(query))

        var xhr = new XMLHttpRequest()
        currentTagRequest = xhr
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                currentTagRequest = null
                try {
                    // console.log("[Booru] Raw response: " + xhr.responseText)
                    var response = JSON.parse(xhr.responseText)
                    response = provider.tagMapFunc(response)
                    // console.log("[Booru] Mapped response: " + JSON.stringify(response))
                    root.tagSuggestion(query, response)
                } catch (e) {
                    console.log("[Booru] Failed to parse response: " + e)
                }
            }
            else if (xhr.readyState === XMLHttpRequest.DONE) {
                console.log("[Booru] Request failed with status: " + xhr.status)
            }
        }

        try {
            // Required for danbooru and konachan
            if (["danbooru", "konachan"].includes(currentProvider)) {
                xhr.setRequestHeader("User-Agent", defaultUserAgent)
            }
            else if (currentProvider == "e621") {
                root.setE621Headers(xhr)
            }
            xhr.send()
        } catch (error) {
            console.log("Could not set User-Agent:", error)
        }
    }
}

