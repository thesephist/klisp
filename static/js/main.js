const {
    Record,
    StoreOf,
    Component,
    ListOf,
    Router,
    render,
} = window.Torus;

const BLOCK = {
    TEXT: 0,
    CODE: 1,
}

//> Debounce coalesces multiple calls to the same function in a short
//  period of time into one call, by cancelling subsequent calls within
//  a given timeframe.
const debounce = (fn, delayMillis) => {
    let lastRun = 0;
    let to = null;
    return (...args) => {
        clearTimeout(to);
        const now = Date.now();
        const dfn = () => {
            lastRun = now;
            fn(...args);
        }
        to = setTimeout(dfn, delayMillis);
    }
}

function message(msg) {
    function close() {
        document.body.removeChild(node);
    }

    const node = render(null, null, jdom`<div class="message paper paper-border-top">
        ${msg}
        <div class="message-buttons">
            <button class="movable accent paper" onclick=${close}>Ok</button>
        </div>
    </div>`);
    document.body.appendChild(node);
}

function confirm(msg, ifOk) {
    function close() {
        document.body.removeChild(node);
    }

    const node = render(null, null, jdom`<div class="message paper paper-border-top">
        ${msg}
        <div class="message-buttons">
            <button class="movable paper" onclick=${close}>No</button>
            <button class="movable accent paper" onclick=${() => {
                close();
                ifOk();
            }}>Yes</button>
        </div>
    </div>`);
    document.body.appendChild(node);
}

class Para extends Record {
    childIndexes() {
        const childIndex = (this.get('index') + this.get('next')) / 2;
        const childNext = this.get('next');
        this.update({next: childIndex});

        return {
            index: childIndex,
            next: childNext,
        }
    }
}

class Doc extends StoreOf(Para) {
    get comparator() {
        return block => block.get('index');
    }
}

function remoteEval(expr) {
    return fetch('/eval', {
        method: 'POST',
        body: expr,
    }).then(resp => resp.text());
}

// Borrowed from thesephist/sandbox, an event handler that does some light
// parentheses matching / deletion on certain events. Used by Component Block.
function handleEditorKeystroke(evt) {
    switch (evt.key) {
        case 'Tab': {
            evt.preventDefault();
            const idx = evt.target.selectionStart;
            if (idx !== null) {
                const input = evt.target.value;
                const front = input.substr(0, idx);
                const back = input.substr(idx);
                evt.target.value = front + '    ' + back;
                evt.target.setSelectionRange(idx + 4, idx + 4);
            }
            break;
        }
        case '(': {
            evt.preventDefault();
            const idx = evt.target.selectionStart;
            if (idx !== null) {
                const input = evt.target.value;
                const front = input.substr(0, idx);
                const back = input.substr(idx);
                evt.target.value = front + '()' + back;
                evt.target.setSelectionRange(idx + 1, idx + 1);
            }
            break;
        }
        case ')': {
            const idx = evt.target.selectionStart;
            if (idx !== null) {
                const input = evt.target.value;
                if (input[idx] === ')') {
                    evt.preventDefault();
                    evt.target.setSelectionRange(idx + 1, idx + 1);
                }
            }
            break;
        }
        case '\'': {
            evt.preventDefault();
            const idx = evt.target.selectionStart;
            if (idx !== null) {
                const input = evt.target.value;
                if (input[idx] === '\'') {
                    evt.preventDefault();
                    evt.target.setSelectionRange(idx + 1, idx + 1);
                } else {
                    const front = input.substr(0, idx);
                    const back = input.substr(idx);
                    // if trying to escape this quote, do not add a pair
                    if (input[idx - 1] === '\'') {
                        evt.target.value = front + '\'' + back;
                    } else {
                        evt.target.value = front + '\'\'' + back;
                    }
                    evt.target.setSelectionRange(idx + 1, idx + 1);
                }
            }
            break;
        }
        case 'Backspace': {
            // Backspace on a opening pair should take its closing sibling wth it
            const idx = evt.target.selectionStart;
            if (idx !== null) {
                const input = evt.target.value;
                if ((input[idx - 1] === '(' && input[idx] === ')')
                    || (input[idx - 1] === '\'' && input[idx] === '\'')) {
                    evt.preventDefault();
                    const front = input.substr(0, idx - 1);
                    const back = input.substr(idx + 1);
                    evt.target.value = front + back;
                    evt.target.setSelectionRange(idx - 1, idx - 1);
                }
            }
            break;
        }
    }
}

class Block extends Component {
    init(para, remover, {addTextBlock, addCodeBlock}) {
        this.editing = false;

        this.evaling = false;
        this.evaled = null;

        this.remover = remover;
        this.addTextBlock = () => addTextBlock(this.record.childIndexes());
        this.addCodeBlock = () => addCodeBlock(this.record.childIndexes());
        this.startEditing = this.startEditing.bind(this);

        this.bind(para, this.render.bind(this));

        // if code block, exec code on first load
        if (this.record.get('type') == BLOCK.CODE && this.evaled == null) {
            this.eval();
        }
    }
    async eval(evt) {
        this.evaling = true;
        this.render();

        try {
            this.evaled = await remoteEval(evt ? evt.target.value : this.record.get('text'));
        } catch (e) {
            this.evaled = 'eval-error';
        }
        this.evaling = false;
        this.render();
    }
    startEditing(evt) {
        // sometimes we click on the block to navigate to a link
        if (evt.target.tagName.toLowerCase() == 'a') {
            return;
        }

        this.editing = true;
        this.render();

        // allow exiting editing mode by clicking elsewhere on the page
        requestAnimationFrame(() => {
            const unEdit = evt => {
                if (!this.node.contains(evt.target)) {
                    this.editing = false;
                    this.render();
                    document.removeEventListener('click', unEdit);
                }
            }
            document.addEventListener('click', unEdit);
        });
    }
    compose() {
        const {type, text} = this.record.summarize();
        const buttons = jdom`<div class="block-buttons"
            onclick=${evt => evt.stopPropagation()}>
            <button onclick=${this.remover}>del</button>
            <button onclick=${this.addTextBlock}>+text</button>
            <button onclick=${this.addCodeBlock}>+code</button>
        </div>`;

        if (type == BLOCK.CODE) {
            return jdom`<div class="block block-code wrap paper ${this.evaling ? 'evaling' : ''}"
                tabIndex=${this.evaling ? -1 : 0}>
                ${buttons}
                <div class="block-code-editor">
                    <div class="p-spacer ${text.endsWith('\n') || !text ? 'padded' : ''}">${text}</div>
                    <textarea
                        class="textarea-code"
                        value=${text}
                        oninput=${evt => this.record.update({
                            text: evt.target.value,
                        })}
                        onkeydown=${evt => {
                            if (evt.key == 'Enter' && (evt.ctrlKey || evt.metaKey)) {
                                this.eval(evt);
                            } else {
                                handleEditorKeystroke(evt);

                                // if evt.preventDefault() was called in handleEditorKeystroke,
                                // the related oninput event will not fire, causing this change
                                // not to be reflected in our data models without this manual update.
                                if (!evt.defaultPrevented) {
                                    this.record.update({
                                        text: evt.target.value,
                                    });
                                }
                            }
                        }} />
                </div>
                <div class="block-code-result">
                    ${this.evaled || '(none)'}
                </div>
            </div>`
        }

        if (this.editing) {
            return jdom`<div class="block block-text-editor">
                <div class="p-spacer ${text.endsWith('\n') || !text ? 'padded' : ''}">${text}</div>
                <textarea
                    class="textarea-text"
                    value=${text}
                    oninput=${evt => this.record.update({
                        text: evt.target.value,
                    })}
                    onkeydown=${evt => {
                        if (
                            evt.key == 'Enter'
                            && (evt.ctrlKey || evt.metaKey)
                            || evt.key == 'Escape'
                        ) {
                            this.editing = false;
                            this.render();
                        }
                    }} />
            </div>`;
        }

        // Render LaTeX equations using KaTeX synchronously with block render
        requestAnimationFrame(() => {
            renderMathInElement(this.node, {
                delimiters: [
                    {left: "$$", right: "$$", display: true},
                    {left: "$", right: "$", display: false},
                    {left: "\\(", right: "\\)", display: false},
                    {left: "\\[", right: "\\]", display: true},
                ],
            });
        });
        return jdom`<div class="block block-text" onclick=${this.startEditing}>
            ${buttons}
            ${Markus(text.trim().split('\n').filter(s => s.trim()).join('\n'))}
        </div>`
    }
}

class Editor extends ListOf(Block) {
    compose() {
        const nodes = this.nodes;
        return jdom`<main class="editor">
            ${this.nodes.length ? this.nodes : jdom`<button class="new-block-button"
                onclick=${() => {
                    this.record.create(null, {
                        type: BLOCK.TEXT,
                        text: '# New doc',
                    })
                }}>+ Start writing</button>`}
        </main>`;
    }
}

class DocList extends Component {
    init() {
        this.docNames = [];

        fetch('/doc/')
            .then(resp => resp.text())
            .then(docNames => {
                this.docNames = docNames.split('\n').filter(s => !!s).sort();
                this.render();
            })
            .catch(e => message(`Error getting doc list: ${e}`));
    }
    compose() {
        return jdom`<ul class="doc-list">
            ${this.docNames.map(name => jdom`<li class="doc-list-li"><a href="/d/${name}"
                onclick=${evt => {
                    evt.preventDefault();
                    router.go('/d/' + name);
                }}>${name}</a></li>`)}
        </ul>`;
    }
}

// Helper fn for a default (test) doc
let index = 0;
function para(text) {
    return new Para({
        type: BLOCK.TEXT,
        text,
        index: index++,
        next: index,
    });
}
function code(text) {
    return new Para({
        type: BLOCK.CODE,
        text,
        index: index++,
        next: index,
    });
}

const MODE = {
    DOC: 0,
    ABOUT: 1,
    LIST: 2,
    NEW: 3,
}

class App extends Component {
    init(router) {
        this.docID = null;
        this.mode = MODE.DOC;

        this.doc = new Doc([
            para('_Loading..._'),
        ]);
        this.editor = new Editor(this.doc, {
            addTextBlock: childIndexes => this.doc.create(null, {
                type: BLOCK.TEXT,
                text: 'Say something...',
                ...childIndexes,
            }),
            addCodeBlock: childIndexes => this.doc.create(null, {
                type: BLOCK.CODE,
                text: '(+ 1 1)',
                ...childIndexes,
            }),
        });

        // This is a bit of a hack, but a good way to catch all events whenever
        // a Para (block) has its contents changed. We could listen to events
        // firing off of this.doc, but those only capture shallow events coming
        // from the Store, not the Records inside.
        const persistDoc = debounce(() => {
            if (this.docID) {
                fetch(`/doc/${this.docID}`, {
                    method: 'PUT',
                    body: JSON.stringify(this.doc.serialize()),
                }).then(resp => {
                    if (resp.status == 404) {
                        // a 404 error is handled elsewhere on load
                    } else if (resp.status !== 200) {
                        message('sync error');
                    }
                });
            } else {
                console.info('Not persisting sandbox doc.');
            }
        }, 500);
        this.doc.addHandler(persistDoc);
        document.addEventListener('input', evt => {
            if (evt.target.tagName.toLowerCase() !== 'textarea') {
                return;
            }
            persistDoc();
        });

        this.bind(router, async ([name, params]) => {
            switch (name) {
                case 'doc': {
                    this.mode = MODE.DOC;
                    this.docID = params.docID;
                    try {
                        const docResp = await fetch('/doc/' + encodeURIComponent(this.docID));
                        if (docResp.status !== 200) {
                            throw new Error('Error loading doc from server');
                        }

                        const docJSON = await docResp.json();
                        this.doc.reset(docJSON.map(blk => new Para(blk)));
                    } catch (e) {
                        message('Couldn\'t load doc');
                    }
                    this.render();
                    break;
                }
                case 'about': {
                    this.mode = MODE.ABOUT;
                    this.render();
                    break;
                }
                case 'list': {
                    this.mode = MODE.LIST;
                    this.render();
                    break;
                }
                case 'new': {
                    this.mode = MODE.NEW;
                    this.render();
                    break;
                }
                default: {
                    this.doc.reset([
                        para('# A tour of Nightvale'),
                        para('*Nightvale* is a rich interactive notebook that runs Klisp (<https://github.com/thesephist/klisp>). You can click on any block of text to edit it as Markdown, or start typing in a code block to write and run a Klisp program.\nFor example, here\'s a simple code block.'),
                        code('(+ 1 2 3 4)'),
                        para('You can tap the `run` button or hit Control/Cmd+Enter to evaluate the program.\nNightvale code snippets can also include more complex structures and macros -- the entire Klisp standard library is available in Nightvale. When you visualize the result, you can also view alternative formats for the output data like tables and graphs.'),
                        code('(def one-to-five (list 1 2 3 4 5))\n(def square (fn (n) (* n n)))\n(map one-to-five square)'),
                        para('In this way, Nightvale can combine data visualizations, literate programs, and prose to communicate interesting ideas interactively.'),
                    ]);
                    break;
                }
            }
        });
    }
    compose() {
        let main = this.editor.node;
        switch (this.mode) {
            case MODE.ABOUT:
                main = jdom`<main>
                    <h1>About Nightvale</h1>
                    <p>
                        Nightvale is an interactive literate programming environment that runs <a
                        href="https://github.com/thesephist/klisp" target="_blank">Klisp</a>, a
                        Scheme-like dialect of lisp that runs on the <a href="https://dotink.co"
                        target="_blank">Ink programming language</a>.  Nightvale is under active
                        development to become a better environment for thinking computationally
                        and quantitatively.
                    </p>
                    <h2>Inspirations and prior work</h2>
                    <p>
                        Interactive, literate programming environments has a rich and illustrious history.
                        Nightvale is a small step from me towards big ideas presented in the following
                        research projects, interesting ideas, and past products.
                    </p>
                    <ul>
                        <li>Light Table and Eve</li>
                        <li>The Clojure REBL</li>
                    </ul>
                    <h2>How it works</h2>
                    <p>
                        This...
                    </p>
                </main>`;
                break;
            case MODE.LIST:
                main = jdom`<main>
                    <h1>Index of docs</h1>
                    ${new DocList().node}
                </main>`;
                break;
            case MODE.NEW: {
                let name = 'doc-' + Math.random().toString().substr(2);
                main = jdom`<main>
                    <h1>New doc</h1>
                    <p>Choose a name, like <code>klisp-sandbox</code>, to open a new doc. It'll be available at <code>nightvale/d/your-doc-name</code>.</p>
                    <form class="inputRow" onsubmit=${async evt => {
                        evt.preventDefault();

                        fetch(`/doc/${name}`, {
                            method: 'POST',
                            body: JSON.stringify([
                                para('# ' + name.replace(/-/g, ' ')).serialize(),
                            ]),
                        }).then(resp => {
                            if (resp.status === 409) {
                                message('Error creating doc: there already exists a doc with this name.');
                                return;
                            } else if (resp.status !== 200) {
                                message(`Error creating doc: status ${resp.status}`);
                                return;
                            }
                            router.go(`/d/${name}`);
                        }).catch(e => {
                            message(`Error creating doc: ${e}`);
                        });
                    }}>
                        <input
                            type="text"
                            class="paper"
                            placeholder="klisp-sandbox"
                            required
                            oninput=${evt => {
                                name = evt.target.value.trim();
                                evt.target.value = name;
                            }} />
                        <button class="movable accent paper">Create</form>
                    </div>
                </main>`;
                break;
            }
        }

        return jdom`<div class="app">
            <header>
                <div class="left">
                    <a href="/">Nightvale</a>
                    ${this.mode == MODE.DOC ? (
                        jdom`<span class="docID" tabIndex=0 onclick=${evt => {
                            router.go('/list')
                        }}> / ${this.docID || 'sandbox'}</span>`
                    ) : null}
                </div>
                <div class="center">
                </div>
                <nav class="right">
                    <a href="/about" onclick=${evt => {
                        evt.preventDefault();
                        router.go('/about');
                    }}>about</a>
                    <a class="desktop" href="https://github.com/thesephist/klisp" target="_blank">github</a>
                    ${this.docID ? jdom`<a href="#" onclick=${evt => {
                        evt.preventDefault();

                        confirm(`Delete the doc ${this.docID} forever?`, () => {
                            fetch(`/doc/${this.docID}`, {
                                method: 'DELETE',
                            }).then(resp => {
                                if (resp.status !== 204) {
                                    message('error:could not delete');
                                    return;
                                }

                                router.go('/list');
                            }).catch(e => {
                                message(`error: could not delete, ${e}`);
                            });
                        });
                    }}>del</a>` : null}
                    <a href="/new" onclick=${evt => {
                        evt.preventDefault();
                        router.go('/new');
                    }}>new</a>
                </nav>
            </header>
            ${main}
            <footer>
                <div class="left">
                    <span class="desktop">Made by </span>
                    <a href="https://thesephist.com/" target="_blank">Linus</a>
                </div>
                <div class="center">
                </div>
                <div class="right">
                    <em>
                        <span class="desktop">Built with </span>
                        <a href="https://github.com/thesephist/klisp" target="_blank">Klisp</a>,
                        <a href="https://dotink.co/" target="_blank">Ink</a>,
                        ${'&'}
                        <a href="https://github.com/thesephist/torus" target="_blank">Torus</a>
                    </em>
                </div>
            </footer>
        </div>`;
    }
}

const router = new Router({
    doc: '/d/:docID',
    about: '/about',
    list: '/list',
    new: '/new',
    default: '/',
});

const app = new App(router);
document.body.appendChild(app.node);

