const {
	Record,
	StoreOf,
	Component,
	ListOf,
	Router,
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
        this.evaled = await remoteEval(evt ? evt.target.value : this.record.get('text'));
        this.evaling = false;
        this.render();
    }
	startEditing(evt) {
		this.editing = true;
		this.render();
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
                        if (evt.key == 'Enter' && (evt.ctrlKey || evt.metaKey)) {
                            this.editing = false;
                            this.render();
                        }
                    }} />
            </div>`;
		}

		return jdom`<div class="block block-text" onclick=${this.startEditing}>
			${buttons}
			${Markus(text.trim())}
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
                        text: '# New document',
                    })
                }}>+ Start writing</button>`}
		</main>`;
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
	NEW: 2,
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

        document.addEventListener('input', debounce(evt => {
            if (evt.target.tagName.toLowerCase() !== 'textarea') {
                return;
            }

            if (this.docID) {
                fetch(`/doc/${this.docID}`, {
                    method: 'POST',
                    body: JSON.stringify(this.doc.serialize()),
                });
            } else {
                // TODO: maybe save to localStorage instead?
                console.info('Not persisting sandbox document.');
            }
        }, 500));

		this.bind(router, async ([name, params]) => {
			switch (name) {
				case 'doc': {
                    this.docID = params.docID;
					try {
						const docResp = await fetch('/doc/' + encodeURIComponent(this.docID));
						const docJSON = await docResp.json();
						this.doc.reset(docJSON.map(blk => new Para(blk)));
					} catch (e) {
						alert('Couldn\'t load doc');
					}
					break;
				}
				case 'about': {
					this.mode = MODE.ABOUT;
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
						para('*Nightvale* is a rich interactive notebook that runs Klisp. You can click on any block of text to edit it as Markdown or modify a program.'),
						code('(+ 1 2 3 4)'),
					]);
					break;
				}
			}
		});
	}
	compose() {
		let main = this.editor.node;
		switch (this.mode) {
			case MODE.NEW: {
				let name = 'doc-' + Math.random().toString().substr(2);
				main = jdom`<main>
					<h1>New doc</h1>
					<p>Create one here.</p>
                    <div class="inputRow">
                        <input
                            type="text"
                            class="paper"
                            placeholder="klisp-sandbox"
                            oninput=${evt => {
                                name = evt.target.value.trim();
                                evt.target.value = name;
                            }} />
                        <button class="movable accent paper"
                            onclick=${async evt => {
                            fetch(`/doc/${name}`, {
                                method: 'POST',
                                body: JSON.stringify([
                                    para('# ' + name).serialize(),
                                ]),
                            }).then(resp => {
                                router.go(`/d/${name}`);
                            }).catch(e => {
                                alert(`Error creating doc: ${e}`);
                            });
                        }}>Create</button>
                    </div>
				</main>`;
				break;
			}
			case MODE.ABOUT:
				main = jdom`<main>
					<h1>About Nightvale</h1>
					<p>Nightvale is an interactive Klisp notebook.</p>
				</main>`;
				break;
		}

		return jdom`<div class="app">
			<header>
				<div class="left">
					<a href="/">Nightvale</a>
                    ${this.mode == MODE.DOC ? (
                        jdom`<span class="docID"> / ${this.docID || 'sandbox'}</span>`
                    ) : null}
				</div>
				<div class="center">
				</div>
				<nav class="right">
                    <a href="/about" onclick=${evt => {
                        evt.preventDefault();
                        router.go('/about');
                    }}>about</a>
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
	new: '/new',
	default: '/',
});

const app = new App(router);
document.body.appendChild(app.node);

