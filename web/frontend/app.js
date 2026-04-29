const state = {
  payload: null,
  activeTab: 'overview',
  followCurrent: true,
  message: '',
  readerSyncInFlight: false,
};

const FOLDER_TO_BOOK = {
  '01fftd': 1,
  '02fotw': 2,
  '03tcok': 3,
  '04tcod': 4,
  '05sots': 5,
  '06tkot': 6,
  '07cd': 7,
  '08tjoh': 8,
  '09tcof': 9,
  '10tdot': 10,
  '11tpot': 11,
  '12tmod': 12,
  '13tplor': 13,
  '14tcok': 14,
  '15tdc': 15,
  '16tlov': 16,
  '17tdoi': 17,
  '18dotd': 18,
  '19wb': 19,
  '20tcon': 20,
  '21votm': 21,
  '22tbos': 22,
  '23mh': 23,
  '24rw': 24,
  '25totw': 25,
  '26tfobm': 26,
  '27v': 27,
  '28thos': 28,
  '29tsoc': 29,
};

const elements = {
  statusLine: document.getElementById('status-line'),
  readerTitle: document.getElementById('reader-title'),
  readerFrame: document.getElementById('reader-frame'),
  summaryGrid: document.getElementById('summary-grid'),
  flowHost: document.getElementById('flow-host'),
  view: document.getElementById('view'),
  messageBar: document.getElementById('message-bar'),
  tabbar: document.getElementById('tabbar'),
  sectionInput: document.getElementById('section-input'),
  commandInput: document.getElementById('command-input'),
  jumpSectionBtn: document.getElementById('jump-section-btn'),
  runCommandBtn: document.getElementById('run-command-btn'),
  newGameBtn: document.getElementById('new-game-btn'),
  loadLastSaveBtn: document.getElementById('load-last-save-btn'),
  saveGameBtn: document.getElementById('save-game-btn'),
};

async function apiState() {
  const response = await fetch('/api/state');
  const data = await response.json();
  if (!response.ok || !data.ok) {
    const error = new Error(data.message || 'Failed to load state.');
    error.responseData = data;
    throw error;
  }
  return data;
}

async function apiAction(payload) {
  const response = await fetch('/api/action', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const data = await response.json();
  if (!response.ok || !data.ok) {
    const error = new Error(data.message || 'Action failed.');
    error.responseData = data;
    throw error;
  }
  return data;
}

function safeArray(value) {
  return Array.isArray(value) ? value : [];
}

function text(value, fallback = '(none)') {
  if (value === null || value === undefined || value === '') {
    return fallback;
  }
  return String(value);
}

function formatMessage(value, fallback = 'Ready.') {
  if (Array.isArray(value)) {
    for (let index = value.length - 1; index >= 0; index -= 1) {
      const item = value[index];
      if (typeof item === 'string' && item.trim()) {
        return item;
      }
    }
    return fallback;
  }

  return text(value, fallback);
}

function getReaderPageInfo() {
  try {
    const href = elements.readerFrame.contentWindow?.location?.href
      || elements.readerFrame.getAttribute('src')
      || '';
    const url = new URL(href, window.location.origin);
    if (url.pathname === '/web/frontend/library.html') {
      return { type: 'library', url: url.pathname };
    }

    const match = url.pathname.match(/^\/books\/lw\/([^/]+)\/sect(\d+)\.htm$/i);
    if (!match) {
      return { type: 'other', url: url.pathname };
    }

    const folder = match[1].toLowerCase();
    return {
      type: 'section',
      url: url.pathname,
      folder,
      bookNumber: FOLDER_TO_BOOK[folder] || null,
      section: Number(match[2]),
    };
  } catch (_error) {
    return null;
  }
}

function updateReaderTitleFromPageInfo(info) {
  if (!info) {
    return;
  }

  if (info.type === 'library') {
    if (!state.payload?.session?.HasState) {
      elements.readerTitle.textContent = 'Reader Home';
    }
    return;
  }

  if (info.type !== 'section') {
    return;
  }

  const payload = state.payload;
  const activeBookNumber = Number(payload?.reader?.BookNumber || 0);
  const activeBookTitle = payload?.reader?.BookTitle || '';
  const title = info.bookNumber === activeBookNumber && activeBookTitle
    ? `Book ${info.bookNumber} - ${activeBookTitle} | Section ${info.section}`
    : `Book ${text(info.bookNumber, '?')} | Section ${info.section}`;
  elements.readerTitle.textContent = title;
}

async function handleReaderNavigation() {
  const info = getReaderPageInfo();
  updateReaderTitleFromPageInfo(info);

  if (!info || info.type !== 'section') {
    return;
  }

  const payload = state.payload;
  if (!payload?.session?.HasState) {
    return;
  }
  if (payload?.pendingFlow?.Active || payload?.combat?.Active) {
    return;
  }

  const currentBook = Number(payload.reader?.BookNumber || 0);
  const currentSection = Number(payload.reader?.Section || 0);
  if (!info.bookNumber || info.bookNumber !== currentBook || info.section === currentSection) {
    return;
  }

  if (state.readerSyncInFlight) {
    return;
  }

  state.readerSyncInFlight = true;
  try {
    state.followCurrent = true;
    const response = await apiAction({ action: 'setSection', section: info.section });
    applyResponse(response);
  } catch (error) {
    handleActionError(error);
  } finally {
    state.readerSyncInFlight = false;
  }
}

function renderSummaryCards(payload) {
  const cards = [];
  if (payload?.session?.HasState) {
    cards.push(['Character', text(payload.character?.Name)]);
    cards.push(['Book', `Book ${payload.reader?.BookNumber} - ${text(payload.reader?.BookTitle, 'Unknown')}`]);
    cards.push(['Section', text(payload.reader?.Section)]);
    cards.push(['END', `${text(payload.character?.EnduranceCurrent, '0')} / ${text(payload.character?.EnduranceMax, '0')}`]);
    cards.push(['Gold', text(payload.inventory?.GoldCrowns, '0')]);
  } else {
    cards.push(['Session', 'No active run']);
    cards.push(['Screen', text(payload?.session?.CurrentScreen, 'welcome')]);
    cards.push(['Saves', String(safeArray(payload?.saves).length)]);
    cards.push(['Engine', text(payload?.app?.Version, '0.8.0')]);
    cards.push(['Mode', payload?.pendingFlow?.Active ? 'Setup Flow' : 'Welcome']);
  }

  elements.summaryGrid.innerHTML = cards.map(([label, value]) => `
    <article class="summary-card">
      <span>${label}</span>
      <strong>${value}</strong>
    </article>
  `).join('');
}

function renderOverview(payload) {
  const campaign = payload.campaign || null;
  const disciplines = [
    ...safeArray(payload.character?.Disciplines),
    ...safeArray(payload.character?.MagnakaiDisciplines),
  ];

  return `
    <section class="panel">
      <h2>Run Overview</h2>
      <div class="kv-grid">
        <div class="kv"><span>Current Screen</span><strong>${text(payload.session?.CurrentScreen)}</strong></div>
        <div class="kv"><span>Rule Set</span><strong>${text(payload.app?.RuleSet)}</strong></div>
        <div class="kv"><span>Combat Skill</span><strong>${text(payload.character?.CombatSkillBase, '0')}</strong></div>
        <div class="kv"><span>Completed Books</span><strong>${safeArray(payload.character?.CompletedBooks).join(', ') || '(none)'}</strong></div>
      </div>
    </section>
    <section class="panel">
      <h2>Disciplines</h2>
      <div class="inventory-list">
        ${disciplines.length ? disciplines.map((item) => `<span class="pill">${item}</span>`).join(' ') : '<p class="muted">(none recorded)</p>'}
      </div>
    </section>
    <section class="panel">
      <h2>Campaign Snapshot</h2>
      ${campaign ? `
        <div class="kv-grid">
          <div class="kv"><span>Difficulty</span><strong>${text(campaign.Difficulty)}</strong></div>
          <div class="kv"><span>Permadeath</span><strong>${campaign.PermadeathEnabled ? 'On' : 'Off'}</strong></div>
          <div class="kv"><span>Sections Visited</span><strong>${text(campaign.SectionsVisited, '0')}</strong></div>
          <div class="kv"><span>Run Style</span><strong>${text(campaign.RunStyle)}</strong></div>
          <div class="kv"><span>Victories</span><strong>${text(campaign.Victories, '0')}</strong></div>
          <div class="kv"><span>Deaths / Rewinds</span><strong>${text(campaign.Deaths, '0')} / ${text(campaign.RewindsUsed, '0')}</strong></div>
        </div>
      ` : '<p class="muted">No campaign summary is available until a run is loaded.</p>'}
    </section>
  `;
}

function renderInventory(payload) {
  const sections = [
    ['Weapons', safeArray(payload.inventory?.Weapons)],
    ['Backpack', safeArray(payload.inventory?.BackpackItems)],
    ['Special', safeArray(payload.inventory?.SpecialItems)],
    ['Pocket', safeArray(payload.inventory?.PocketSpecialItems)],
    ['Herb Pouch', safeArray(payload.inventory?.HerbPouchItems)],
  ];

  return `
    <section class="panel">
      <h2>Inventory</h2>
      <div class="inventory-grid">
        ${sections.map(([title, items]) => `
          <article class="panel">
            <h2>${title}</h2>
            <div class="inventory-list">
              ${items.length ? items.map((item) => `<span class="pill">${item}</span>`).join(' ') : '<p class="muted">(empty)</p>'}
            </div>
          </article>
        `).join('')}
      </div>
    </section>
  `;
}

function renderCombat(payload) {
  const combat = payload.combat || {};
  const active = Boolean(combat.Active);
  const rounds = safeArray(combat.Log).slice(-8);
  const rows = [
    ['Enemy', text(combat.EnemyName)],
    ['Enemy CS', text(combat.EnemyCombatSkill, '0')],
    ['Enemy END', `${text(combat.EnemyEnduranceCurrent, '0')} / ${text(combat.EnemyEnduranceMax, '0')}`],
    ['Weapon', text(combat.EquippedWeapon)],
    ['Mindblast', combat.UseMindblast ? 'On' : 'Off'],
    ['Evade', combat.CanEvade ? 'Available' : 'No'],
    ['Rounds Logged', String(safeArray(combat.Log).length)],
    ['END Loss Multiplier', text(combat.PlayerEnduranceLossMultiplier, '1')],
  ];

  return `
    <section class="panel">
      <h2>${active ? 'Combat Controls' : 'Start Tracked Combat'}</h2>
      ${active ? `
        <div class="flow-actions combat-actions">
          <button type="button" data-combat-action="combatRound">Resolve Round</button>
          <button type="button" data-combat-action="combatAuto">Auto Resolve</button>
          <button type="button" data-combat-action="combatEvade" ${combat.CanEvade ? '' : 'disabled'}>Evade</button>
          <button type="button" class="button-secondary" data-combat-action="combatStop">Stop Tracking</button>
        </div>
      ` : `
        <p class="muted">Use the tracked combat form when the book calls for a fight and you want the browser UI to drive setup instead of the terminal prompt flow.</p>
        <form id="combat-start-form" class="flow-form">
          <div class="flow-grid">
            <label class="flow-field">
              <span>Enemy name</span>
              <input id="combat-enemy-name" type="text" placeholder="Enemy name">
            </label>
            <label class="flow-field">
              <span>Enemy Combat Skill</span>
              <input id="combat-enemy-cs" type="number" min="0" value="16">
            </label>
            <label class="flow-field">
              <span>Enemy Endurance</span>
              <input id="combat-enemy-end" type="number" min="1" value="20">
            </label>
          </div>
          <div class="flow-actions">
            <button type="submit">Start Combat</button>
          </div>
        </form>
      `}
    </section>
    <section class="panel">
      <h2>Combat</h2>
      <div class="kv-grid">
        <div class="kv"><span>Status</span><strong>${active ? 'Active' : 'Inactive'}</strong></div>
        ${rows.map(([label, value]) => `<div class="kv"><span>${label}</span><strong>${value}</strong></div>`).join('')}
      </div>
    </section>
    <section class="panel">
      <h2>Recent Combat Rounds</h2>
      ${rounds.length ? rounds.map((round) => `
        <div class="history-row">
          <strong>Round ${text(round.Round, '?')}</strong>
          <div class="history-meta">Roll ${text(round.Roll, '?')} | Ratio ${text(round.Ratio, '?')} | Enemy Loss ${text(round.EnemyLoss, '0')} | Player Loss ${text(round.PlayerLoss, '0')}</div>
        </div>
      `).join('') : '<p class="muted">No combat rounds are recorded for the current fight.</p>'}
    </section>
  `;
}

function renderSaves(payload) {
  const saves = safeArray(payload.saves);
  const currentSavePath = text(payload.session?.SavePath, '');
  const hasState = Boolean(payload.session?.HasState);
  return `
    <section class="panel">
      <h2>Save Controls</h2>
      ${hasState ? `
        <div class="kv-grid">
          <div class="kv"><span>Current Save Path</span><strong>${currentSavePath || '(not set yet)'}</strong></div>
          <div class="kv"><span>Active Character</span><strong>${text(payload.character?.Name)}</strong></div>
        </div>
        <form id="save-as-form" class="flow-form">
          <label class="flow-field">
            <span>Save path</span>
            <input id="save-as-path" type="text" value="${payload.session?.SavePath || ''}" placeholder="C:\\Scripts\\Lone Wolf\\saves\\my-run.json">
          </label>
          <div class="flow-actions">
            <button type="submit">Save To Path</button>
            <button type="button" class="button-secondary" id="save-prompt-btn">Choose Path</button>
          </div>
        </form>
      ` : '<p class="muted">Load a run or start a new one before saving.</p>'}
    </section>
    <section class="panel">
      <h2>Saves</h2>
      ${saves.length ? saves.map((save) => `
        <article class="save-row">
          <strong>${text(save.Name)}</strong>
          <div class="save-meta">
            ${save.BookNumber ? `Book ${save.BookNumber}` : 'Book ?'} |
            ${text(save.RuleSet, '?')} |
            ${text(save.Difficulty, '?')} |
            ${text(save.CharacterName, '')}
          </div>
          <div class="save-actions">
            <button type="button" data-load-path="${save.FullName}">Load</button>
            <span class="muted">${text(save.LastWriteTime, '')}</span>
          </div>
        </article>
      `).join('') : '<p class="muted">No saves found.</p>'}
    </section>
  `;
}

function renderHistory(payload) {
  const entries = safeArray(payload.history).slice().reverse();
  return `
    <section class="panel">
      <h2>Recent Combat History</h2>
      ${entries.length ? entries.map((entry) => `
        <article class="history-row">
          <strong>${text(entry.EnemyName)}</strong>
          <div class="history-meta">
            ${text(entry.Outcome)} | ${text(entry.Weapon)} | ${entry.BookNumber ? `Book ${entry.BookNumber}` : ''} ${entry.Section ? `Section ${entry.Section}` : ''}
          </div>
          <div class="history-meta">
            Rounds ${text(entry.RoundCount, '0')} | Ratio ${text(entry.CombatRatio, '0')} | Player END ${text(entry.PlayerEnd, '0')} | Enemy END ${text(entry.EnemyEnd, '0')}
          </div>
        </article>
      `).join('') : '<p class="muted">No combat history recorded yet.</p>'}
    </section>
  `;
}

function renderNotes(payload) {
  const notes = safeArray(payload.notes);
  return `
    <section class="panel">
      <h2>Notes</h2>
      <form id="note-form" class="flow-form">
        <label class="flow-field">
          <span>Add a note</span>
          <input id="note-input" type="text" maxlength="240" placeholder="Track a clue, item, or route reminder">
        </label>
        <div class="flow-actions">
          <button type="submit">Add Note</button>
        </div>
      </form>
    </section>
    <section class="panel">
      <h2>Recorded Notes</h2>
      ${notes.length ? notes.map((note, index) => `
        <article class="note-row">
          <strong>Note ${index + 1}</strong>
          <div class="history-meta">${text(note, '')}</div>
          <div class="save-actions">
            <button type="button" class="button-secondary" data-remove-note="${index + 1}">Remove</button>
          </div>
        </article>
      `).join('') : '<p class="muted">No notes recorded.</p>'}
    </section>
  `;
}

function renderFlowSummary(summary) {
  if (!summary) {
    return '';
  }

  const entries = [];
  if (summary.Difficulty) {
    entries.push(['Difficulty', summary.Difficulty]);
  }
  entries.push(['Permadeath', summary.Permadeath ? 'On' : 'Off']);
  if (summary.Name) {
    entries.push(['Name', summary.Name]);
  }
  if (summary.BookNumber) {
    entries.push(['Book', `Book ${summary.BookNumber}`]);
  }
  if (summary.StartSection) {
    entries.push(['Start', `Section ${summary.StartSection}`]);
  }

  return `
    <div class="flow-summary">
      ${entries.map(([label, value]) => `<span class="pill subtle-pill">${label}: ${value}</span>`).join('')}
    </div>
  `;
}

function renderFlowConfirm(flow) {
  return `
    <form id="flow-form" class="flow-form">
      <div class="flow-copy">
        <p>${text(flow.Prompt, '')}</p>
      </div>
      <div class="flow-actions">
        <button type="submit">${text(flow.SubmitLabel, 'Continue')}</button>
        <button type="button" class="button-secondary" data-flow-cancel>${text(flow.CancelLabel, 'Cancel')}</button>
      </div>
    </form>
  `;
}

function renderFlowRunConfig(flow) {
  const options = safeArray(flow.Options);
  return `
    <form id="flow-form" class="flow-form">
      <div class="flow-options">
        ${options.map((option) => `
          <label class="flow-option">
            <input type="radio" name="difficulty" value="${option.Value}" ${option.Value === flow.SelectedDifficulty ? 'checked' : ''}>
            <span>
              <strong>${option.Label}</strong>
              <small>${text(option.Description, '')}</small>
            </span>
          </label>
        `).join('')}
      </div>
      <label class="flow-checkbox">
        <input id="flow-permadeath" type="checkbox" ${flow.SelectedPermadeath ? 'checked' : ''}>
        <span>Enable permadeath for this run</span>
      </label>
      <div class="flow-actions">
        <button type="submit">${text(flow.SubmitLabel, 'Next')}</button>
        <button type="button" class="button-secondary" data-flow-cancel>${text(flow.CancelLabel, 'Cancel')}</button>
      </div>
    </form>
  `;
}

function renderFlowIdentity(flow) {
  const values = flow.Values || {};
  const bookOptions = safeArray(flow.BookOptions);
  return `
    <form id="flow-form" class="flow-form">
      <div class="flow-grid">
        <label class="flow-field">
          <span>Character name</span>
          <input id="flow-name" type="text" value="${text(values.Name, 'Lone Wolf')}" maxlength="60">
        </label>
        <label class="flow-field">
          <span>Starting book</span>
          <select id="flow-book-number">
            ${bookOptions.map((option) => `<option value="${option.Value}" ${Number(option.Value) === Number(values.BookNumber) ? 'selected' : ''}>${option.Label}</option>`).join('')}
          </select>
        </label>
        <label class="flow-field">
          <span>Starting section</span>
          <input id="flow-start-section" type="number" min="1" value="${text(values.StartSection, '1')}">
        </label>
      </div>
      <div class="flow-actions">
        <button type="submit">${text(flow.SubmitLabel, 'Next')}</button>
        <button type="button" class="button-secondary" data-flow-cancel>${text(flow.CancelLabel, 'Cancel')}</button>
      </div>
    </form>
  `;
}

function renderFlowSelectMany(flow) {
  const options = safeArray(flow.Options);
  const selected = new Set(safeArray(flow.Selected).map((value) => Number(value)));
  return `
    <form id="flow-form" class="flow-form">
      <div class="flow-copy">
        <p>Choose exactly ${text(flow.RequiredCount, '0')} ${text(flow.SelectionKind, 'entries')}.</p>
      </div>
      <div class="flow-options">
        ${options.map((option) => `
          <label class="flow-option">
            <input type="checkbox" name="flow-select" value="${option.Value}" ${selected.has(Number(option.Value)) ? 'checked' : ''}>
            <span>
              <strong>${option.Label}</strong>
              <small>${text(option.Description, '')}</small>
            </span>
          </label>
        `).join('')}
      </div>
      <div class="flow-actions">
        <button type="submit">${text(flow.SubmitLabel, 'Next')}</button>
        <button type="button" class="button-secondary" data-flow-cancel>${text(flow.CancelLabel, 'Cancel')}</button>
      </div>
    </form>
  `;
}

function renderFlowPrompt(flow) {
  const prompt = flow.Prompt || null;
  if (!prompt) {
    return `
      <form id="flow-form" class="flow-form">
        <div class="flow-copy">
          <p>${text(flow.Description, 'Continue into the startup package.')}</p>
        </div>
        <div class="flow-actions">
          <button type="submit">${text(flow.SubmitLabel, 'Continue')}</button>
          <button type="button" class="button-secondary" data-flow-cancel>${text(flow.CancelLabel, 'Cancel')}</button>
        </div>
      </form>
    `;
  }

  let control = '';
  if (prompt.PromptType === 'yesno') {
    const defaultYes = prompt.Default !== false;
    control = `
      <div class="flow-options compact-options">
        <label class="flow-option">
          <input type="radio" name="flow-prompt-value" value="yes" ${defaultYes ? 'checked' : ''}>
          <span><strong>Yes</strong></span>
        </label>
        <label class="flow-option">
          <input type="radio" name="flow-prompt-value" value="no" ${defaultYes ? '' : 'checked'}>
          <span><strong>No</strong></span>
        </label>
      </div>
    `;
  } else if (prompt.PromptType === 'int') {
    const min = prompt.Min ?? '';
    const max = prompt.Max ?? '';
    const value = prompt.Default ?? '';
    control = `<input id="flow-prompt-value" type="number" min="${min}" max="${max}" value="${value}">`;
  } else {
    const value = prompt.Default ?? '';
    control = `<input id="flow-prompt-value" type="text" value="${value}">`;
  }

  const hint = [];
  if (prompt.PromptType) {
    hint.push(`Input type: ${prompt.PromptType}`);
  }
  if (prompt.Min !== null && prompt.Min !== undefined) {
    hint.push(`Min ${prompt.Min}`);
  }
  if (prompt.Max !== null && prompt.Max !== undefined) {
    hint.push(`Max ${prompt.Max}`);
  }

  return `
    <form id="flow-form" class="flow-form">
      <div class="flow-copy">
        <p>${text(prompt.Prompt, flow.Description)}</p>
        ${hint.length ? `<p class="muted">${hint.join(' | ')}</p>` : ''}
      </div>
      <div class="flow-field">
        ${control}
      </div>
      <div class="flow-actions">
        <button type="submit">${text(flow.SubmitLabel, 'Continue')}</button>
        <button type="button" class="button-secondary" data-flow-cancel>${text(flow.CancelLabel, 'Cancel')}</button>
      </div>
    </form>
  `;
}

function renderPendingFlow(payload) {
  const flow = payload?.pendingFlow || null;
  if (!flow?.Active) {
    elements.flowHost.innerHTML = '';
    elements.flowHost.classList.add('hidden');
    return;
  }

  let body = '';
  switch (flow.Mode) {
    case 'confirm':
      body = renderFlowConfirm(flow);
      break;
    case 'runConfig':
      body = renderFlowRunConfig(flow);
      break;
    case 'identity':
      body = renderFlowIdentity(flow);
      break;
    case 'selectMany':
      body = renderFlowSelectMany(flow);
      break;
    case 'prompt':
      body = renderFlowPrompt(flow);
      break;
    default:
      body = `
        <form id="flow-form" class="flow-form">
          <div class="flow-copy">
            <p>This flow step is not rendered yet.</p>
          </div>
          <div class="flow-actions">
            <button type="button" class="button-secondary" data-flow-cancel>Cancel</button>
          </div>
        </form>
      `;
      break;
  }

  elements.flowHost.innerHTML = `
    <section class="panel flow-panel">
      <div class="flow-header">
        <div>
          <p class="eyebrow">Structured Flow</p>
          <h2>${text(flow.Title, 'Setup')}</h2>
        </div>
        <span class="flow-step">${text(flow.Step, '')}</span>
      </div>
      <p class="flow-description">${text(flow.Description, '')}</p>
      ${renderFlowSummary(flow.Summary)}
      ${body}
    </section>
  `;
  elements.flowHost.classList.remove('hidden');
  bindFlowEvents(flow);
}

function collectFlowPayload(flow) {
  switch (flow.Mode) {
    case 'confirm':
      return { confirm: true };
    case 'runConfig': {
      const difficulty = document.querySelector('input[name="difficulty"]:checked')?.value || 'Normal';
      const allowPermadeath = difficulty !== 'Story';
      return {
        difficulty,
        permadeath: allowPermadeath && Boolean(document.getElementById('flow-permadeath')?.checked),
      };
    }
    case 'identity':
      return {
        name: document.getElementById('flow-name')?.value || 'Lone Wolf',
        bookNumber: Number(document.getElementById('flow-book-number')?.value || 1),
        startSection: Number(document.getElementById('flow-start-section')?.value || 1),
      };
    case 'selectMany':
      return {
        selected: Array.from(document.querySelectorAll('input[name="flow-select"]:checked')).map((input) => Number(input.value)),
      };
    case 'prompt': {
      const prompt = flow.Prompt || null;
      if (!prompt) {
        return {};
      }

      if (prompt.PromptType === 'yesno') {
        const selected = document.querySelector('input[name="flow-prompt-value"]:checked')?.value;
        return { response: selected === 'yes' };
      }

      if (prompt.PromptType === 'int') {
        const raw = document.getElementById('flow-prompt-value')?.value ?? '';
        return { response: raw === '' ? null : Number(raw) };
      }

      return { response: document.getElementById('flow-prompt-value')?.value ?? '' };
    }
    default:
      return {};
  }
}

function bindFlowEvents(flow) {
  const form = document.getElementById('flow-form');
  if (form) {
    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      try {
        const response = await apiAction({ action: 'submitFlow', data: collectFlowPayload(flow) });
        applyResponse(response);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  document.querySelectorAll('[data-flow-cancel]').forEach((button) => {
    button.addEventListener('click', async () => {
      try {
        const response = await apiAction({ action: 'cancelFlow' });
        applyResponse(response);
      } catch (error) {
        handleActionError(error);
      }
    });
  });
}

function renderView() {
  const payload = state.payload;
  if (!payload) {
    elements.view.innerHTML = '<section class="panel"><h2>Loading</h2><p class="muted">Waiting for the local Lone Wolf web session.</p></section>';
    return;
  }

  if (!payload.session?.HasState) {
    elements.view.innerHTML = `
      <section class="panel">
        <h2>No Active Run</h2>
        <p class="muted">Load your last save, start a new run, or keep the reader open on the library while the web migration keeps growing into a full play surface.</p>
      </section>
      ${renderSaves(payload)}
    `;
  } else {
    switch (state.activeTab) {
      case 'inventory':
        elements.view.innerHTML = renderInventory(payload);
        break;
      case 'combat':
        elements.view.innerHTML = renderCombat(payload);
        break;
      case 'saves':
        elements.view.innerHTML = renderSaves(payload);
        break;
      case 'history':
        elements.view.innerHTML = renderHistory(payload);
        break;
      case 'notes':
        elements.view.innerHTML = renderNotes(payload);
        break;
      default:
        elements.view.innerHTML = renderOverview(payload);
        break;
    }
  }

  bindDynamicViewEvents(payload);
}

function bindDynamicViewEvents(payload) {
  document.querySelectorAll('[data-load-path]').forEach((button) => {
    button.addEventListener('click', async () => {
      try {
        const result = await apiAction({ action: 'loadGame', path: button.dataset.loadPath });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  });

  const noteForm = document.getElementById('note-form');
  if (noteForm) {
    noteForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      const textValue = document.getElementById('note-input')?.value?.trim() || '';
      if (!textValue) {
        setMessage('Enter note text first.', true);
        return;
      }
      try {
        const result = await apiAction({ action: 'addNote', text: textValue });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  document.querySelectorAll('[data-remove-note]').forEach((button) => {
    button.addEventListener('click', async () => {
      try {
        const result = await apiAction({ action: 'removeNote', index: Number(button.dataset.removeNote) });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  });

  const saveAsForm = document.getElementById('save-as-form');
  if (saveAsForm) {
    saveAsForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      const path = document.getElementById('save-as-path')?.value?.trim() || '';
      if (!path) {
        setMessage('Enter a save path first.', true);
        return;
      }
      try {
        const result = await apiAction({ action: 'saveGame', path });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  const savePromptButton = document.getElementById('save-prompt-btn');
  if (savePromptButton) {
    savePromptButton.addEventListener('click', async () => {
      try {
        const result = await apiAction({ action: 'saveGame', promptForPath: true });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  const combatStartForm = document.getElementById('combat-start-form');
  if (combatStartForm) {
    combatStartForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      const enemyName = document.getElementById('combat-enemy-name')?.value?.trim() || '';
      const enemyCombatSkill = Number(document.getElementById('combat-enemy-cs')?.value || 0);
      const enemyEndurance = Number(document.getElementById('combat-enemy-end')?.value || 0);
      if (!enemyName) {
        setMessage('Enter an enemy name first.', true);
        return;
      }
      try {
        const result = await apiAction({
          action: 'startCombat',
          enemyName,
          enemyCombatSkill,
          enemyEndurance,
        });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  }

  document.querySelectorAll('[data-combat-action]').forEach((button) => {
    button.addEventListener('click', async () => {
      try {
        const result = await apiAction({ action: button.dataset.combatAction });
        applyResponse(result);
      } catch (error) {
        handleActionError(error);
      }
    });
  });
}

function syncReader(payload) {
  const url = payload?.reader?.Url || '/web/frontend/library.html';
  elements.readerTitle.textContent = payload?.session?.HasState
    ? `Book ${payload.reader.BookNumber} - ${text(payload.reader.BookTitle)} | Section ${text(payload.reader.Section)}`
    : 'Reader Home';

  const current = elements.readerFrame.getAttribute('src');
  if (current !== url && state.followCurrent !== false) {
    elements.readerFrame.setAttribute('src', url);
  }
}

function setMessage(message, isError = false) {
  state.message = message || '';
  elements.messageBar.textContent = message || 'Ready.';
  elements.messageBar.style.color = isError ? 'var(--danger)' : 'var(--muted)';
}

function applyResponse(response) {
  state.payload = response.payload;
  elements.statusLine.textContent = `Screen: ${text(response.payload?.session?.CurrentScreen, 'welcome')} | Engine ${text(response.payload?.app?.Version, '0.8.0')}`;
  elements.saveGameBtn.disabled = !response.payload?.session?.HasState;
  renderSummaryCards(response.payload);
  renderPendingFlow(response.payload);
  syncReader(response.payload);
  renderView();
  setMessage(formatMessage(response.message, 'Ready.'));
}

function handleActionError(error) {
  if (error?.responseData?.payload) {
    applyResponse(error.responseData);
  }
  setMessage(error.message || 'Action failed.', true);
}

async function refreshState() {
  try {
    const response = await apiState();
    applyResponse(response);
  } catch (error) {
    handleActionError(error);
  }
}

function attachEvents() {
  elements.tabbar.querySelectorAll('button').forEach((button) => {
    button.addEventListener('click', () => {
      state.activeTab = button.dataset.tab;
      elements.tabbar.querySelectorAll('button').forEach((item) => item.classList.toggle('active', item === button));
      renderView();
    });
  });

  document.querySelectorAll('[data-screen]').forEach((button) => {
    button.addEventListener('click', async () => {
      try {
        const response = await apiAction({ action: 'showScreen', name: button.dataset.screen });
        applyResponse(response);
      } catch (error) {
        handleActionError(error);
      }
    });
  });

  document.querySelector('[data-action="open-library"]').addEventListener('click', () => {
    state.followCurrent = false;
    elements.readerFrame.setAttribute('src', '/web/frontend/library.html');
    elements.readerTitle.textContent = 'Reader Home';
  });

  document.querySelector('[data-action="follow-current"]').addEventListener('click', () => {
    state.followCurrent = true;
    if (state.payload) {
      syncReader(state.payload);
    }
  });

  elements.readerFrame.addEventListener('load', () => {
    void handleReaderNavigation();
  });

  document.querySelector('[data-action="reload-state"]').addEventListener('click', refreshState);

  elements.newGameBtn.addEventListener('click', async () => {
    try {
      const response = await apiAction({ action: 'startNewGameWizard' });
      applyResponse(response);
    } catch (error) {
      handleActionError(error);
    }
  });

  elements.loadLastSaveBtn.addEventListener('click', async () => {
    try {
      const response = await apiAction({ action: 'loadLastSave' });
      applyResponse(response);
    } catch (error) {
      handleActionError(error);
    }
  });

  elements.saveGameBtn.addEventListener('click', async () => {
    try {
      const response = await apiAction({ action: 'saveGame' });
      applyResponse(response);
    } catch (error) {
      handleActionError(error);
    }
  });

  elements.jumpSectionBtn.addEventListener('click', async () => {
    const section = Number(elements.sectionInput.value || 0);
    if (!section) {
      setMessage('Enter a section number first.', true);
      return;
    }
    try {
      const response = await apiAction({ action: 'setSection', section });
      state.followCurrent = true;
      applyResponse(response);
    } catch (error) {
      handleActionError(error);
    }
  });

  elements.runCommandBtn.addEventListener('click', async () => {
    const command = elements.commandInput.value.trim();
    if (!command) {
      setMessage('Enter a safe web command first.', true);
      return;
    }
    try {
      const response = await apiAction({ action: 'safeCommand', command });
      state.followCurrent = command.startsWith('set ');
      applyResponse(response);
    } catch (error) {
      handleActionError(error);
    }
  });
}

attachEvents();
refreshState();
