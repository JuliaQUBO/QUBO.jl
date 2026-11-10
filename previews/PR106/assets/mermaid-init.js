(function () {
    function renderMermaidDiagrams() {
        if (!document.querySelector(".mermaid")) {
            return;
        }

        import("https://cdn.jsdelivr.net/npm/mermaid@10.9.6/dist/mermaid.esm.min.mjs")
            .then(function (module) {
                var mermaid = module.default;
                mermaid.initialize({ startOnLoad: false, theme: "neutral" });
                return mermaid.run({ querySelector: ".mermaid" });
            })
            .catch(function (error) {
                console.error("Failed to render Mermaid diagrams", error);
            });
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", renderMermaidDiagrams);
    } else {
        renderMermaidDiagrams();
    }
})();
