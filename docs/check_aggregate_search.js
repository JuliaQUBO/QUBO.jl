// Run against a completed aggregate: node docs/check_aggregate_search.js /path/to/aggregate
// Exercise the shipped FlexSearch widget and navigation handlers with a small DOM adapter.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(process.argv[2]);
const packages = ['QUBO.jl', 'ToQUBO.jl', 'QUBODrivers.jl', 'QUBOTools.jl', 'QUBODecomposition.jl'];
const entries = JSON.parse(fs.readFileSync(path.join(root, 'index.json')));
for (const pkg of packages) {
    const channel = fs.existsSync(path.join(root, pkg, 'stable')) ? 'stable' : 'dev';
    const refs = entries.filter(e => e.ref.startsWith(`/QUBO.jl/${pkg}/`));
    assert(refs.length > 0, `${pkg} contributes search results`);
    assert(refs.every(e => e.ref.startsWith(`/QUBO.jl/${pkg}/${channel}/`)), `${pkg} uses only ${channel}`);
}
const decompositionChannel = fs.existsSync(path.join(root, 'QUBODecomposition.jl', 'stable')) ? 'stable' : 'dev';

class Element {
    constructor() {
        this.handlers = {}; this.attributes = {}; this.children = []; this.dataset = {};
        this.classes = new Set(); this.value = '';
        this.classList = {
            add: c => this.classes.add(c), remove: c => this.classes.delete(c),
            toggle: c => this.classes.has(c) ? this.classes.delete(c) : this.classes.add(c),
        };
    }
    addEventListener(event, handler) { this.handlers[event] = handler; }
    setAttribute(key, value) { this.attributes[key] = value; }
    appendChild(child) { this.children.push(child); child.parentElement = this; }
    replaceChildren(...children) { this.children = children; }
    fire(event, data = {}) { this.handlers[event](data); }
}
const elements = Object.fromEntries(['search-input', 'search-result-container', 'multidoc-toggler', 'nav-items']
    .map(id => [id, new Element()]));
const body = new Element();
const dropdown = new Element();
const label = new Element();
label.parentElement = dropdown;
label.matches = selector => selector === '.dropdown-label' ||
    (selector === '.nav-expanded > .dropdown-label' && dropdown.classes.has('nav-expanded'));
const requests = [];
const context = {
    window: {MULTIDOCUMENTER_ROOT_PATH: '/QUBO.jl/'},
    document: {
        readyState: 'interactive', body,
        getElementById: id => elements[id], createElement: () => new Element(),
        getElementsByClassName: () => [label],
    },
    console: {log() {}, time() {}, timeEnd() {}},
    setTimeout: callback => callback(),
    fetch: async url => {
        assert(url.startsWith('/QUBO.jl/search-data/'), 'search respects repository base path');
        requests.push(url);
        return {ok: true, json: async () => JSON.parse(fs.readFileSync(path.join(root, url.slice('/QUBO.jl/'.length))))};
    },
};
vm.createContext(context);
for (const asset of ['flexsearch.bundle.js', 'flexsearch_integration.js', 'multidoc_injector.js']) {
    vm.runInContext(fs.readFileSync(path.join(root, 'assets/default', asset), 'utf8'), context);
}
async function check() {
    elements['search-input'].fire('focus');
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(requests.length, 5);
    assert.equal(elements['search-input'].attributes.placeholder, 'Search everywhere...');
    elements['search-input'].value = 'stagnation';
    elements['search-input'].fire('keyup');
    const targets = elements['search-result-container'].children.map(li => li.children[0].attributes.href);
    const target = targets.find(ref => ref.startsWith(`/QUBO.jl/QUBODecomposition.jl/${decompositionChannel}/`));
    assert(target, 'distinctive decomposition term returns the selected manual channel');
    const [page, anchor] = target.split('#');
    const html = fs.readFileSync(path.join(root, page.slice('/QUBO.jl/'.length), 'index.html'), 'utf8');
    assert(anchor && html.includes(`id="${anchor}"`), 'result targets a real page and anchor');
    elements['search-input'].value = 'quadratization';
    elements['search-input'].fire('keyup');
    assert(elements['search-result-container'].children.some(li =>
        li.children[0].attributes.href.startsWith('/QUBO.jl/ToQUBO.jl/stable/')), 'released compiler remains searchable in stable');
    elements['multidoc-toggler'].fire('click');
    assert(elements['nav-items'].classes.has('hidden-on-mobile'));
    elements['multidoc-toggler'].fire('click');
    assert(!elements['nav-items'].classes.has('hidden-on-mobile'));
    body.fire('click', {target: label});
    assert(dropdown.classes.has('nav-expanded'));
    body.fire('click', {target: label});
    assert(!dropdown.classes.has('nav-expanded'));
    console.log(`PASS: five package channels, actual search widget (${target}), stable results, base path and navigation handlers`);
}
check().catch(error => { console.error(error); process.exitCode = 1; });
