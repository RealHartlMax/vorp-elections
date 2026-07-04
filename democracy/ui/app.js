const app = document.getElementById('app');
const titleEl = document.getElementById('title');
const subtitleEl = document.getElementById('subtitle');
const closeBtn = document.getElementById('closeBtn');
const modeVoteBtn = document.getElementById('modeVote');
const modeRunBtn = document.getElementById('modeRun');
const modeResultsBtn = document.getElementById('modeResults');
const scopeRow = document.getElementById('scopeRow');
const scopeLabel = document.getElementById('scopeLabel');
const scopeSelect = document.getElementById('scopeSelect');
const statusBanner = document.getElementById('statusBanner');
const positionLabel = document.getElementById('positionLabel');
const candidateLabel = document.getElementById('candidateLabel');
const positionList = document.getElementById('positionList');
const candidateCard = document.getElementById('candidateCard');
const candidateList = document.getElementById('candidateList');
const submitBtn = document.getElementById('submitBtn');
const registerActions = document.getElementById('registerActions');
const registerBtn = document.getElementById('registerBtn');

app.classList.add('hidden');
app.style.display = 'none';

const hideApp = () => {
  app.classList.add('hidden');
  app.style.display = 'none';
  state.open = false;
};

const showApp = () => {
  app.classList.remove('hidden');
  app.style.display = 'flex';
  state.open = true;
};

let resourceName = 'democracy';
let state = {
  open: false,
  mode: 'vote',
  city: '',
  region: '',
  gameState: '',
  labels: {},
  positions: [],
  selectedPosition: null,
  selectedCandidate: null,
  candidates: [],
  resultScopes: [],
  selectedScope: null,
  currentJurisdiction: null,
  autoSelectFirst: false,
  adminSelectedPositions: new Set(),
};

const showStatus = (message) => {
  if (!message) {
    statusBanner.classList.add('hidden');
    statusBanner.textContent = '';
    return;
  }

  statusBanner.textContent = message;
  statusBanner.classList.remove('hidden');
};

const renderResultsRows = (rows = []) => {
  candidateList.innerHTML = '';

  if (!rows.length) {
    const line = document.createElement('div');
    line.textContent = state.labels.results_empty || 'No results yet';
    candidateList.appendChild(line);
    return;
  }

  for (const row of rows) {
    const line = document.createElement('div');
    line.textContent = `${row.name} - ${row.votes} ${state.labels.votes_suffix || 'votes'}`;
    candidateList.appendChild(line);
  }
};

const loadResultsForScope = async (scopeObj) => {
  if (!scopeObj || !state.selectedPosition || !state.currentJurisdiction) {
    return;
  }

  const payload = await post('getResultsData', {
    position: state.selectedPosition.name,
    jurisdiction: state.currentJurisdiction,
    location: scopeObj.value,
    state: scopeObj.state,
  });

  renderResultsRows(payload?.rows || []);
};

const loadResultScopes = async (position) => {
  const payload = await post('getResultsScopes', { position: position.name });
  state.currentJurisdiction = payload?.jurisdiction || 'local';
  state.resultScopes = payload?.scopes || [];

  scopeSelect.innerHTML = '';
  for (const scopeObj of state.resultScopes) {
    const option = document.createElement('option');
    option.value = JSON.stringify(scopeObj);
    option.textContent = scopeObj.label;
    scopeSelect.appendChild(option);
  }

  const hideScope = state.resultScopes.length <= 1 || state.currentJurisdiction === 'federal';
  scopeRow.classList.toggle('hidden', hideScope);

  if (state.resultScopes.length > 0) {
    state.selectedScope = state.resultScopes[0];
    await loadResultsForScope(state.selectedScope);
  } else {
    state.selectedScope = null;
    renderResultsRows([]);
  }
};

const selectPosition = async (item) => {
  state.selectedPosition = item;
  state.selectedCandidate = null;
  renderPositions();

  if (state.mode === 'results') {
    await loadResultScopes(item);
    return;
  }

  if (state.mode === 'vote') {
    const payload = await post('getCandidates', { position: item.name });
    state.candidates = payload?.candidates || [];
    renderCandidates();
  }
};

const post = async (endpoint, data = {}) => {
  const response = await fetch(`https://${resourceName}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  });
  return response.json();
};

const setMode = async (mode) => {
  state.mode = mode;
  state.selectedPosition = null;
  state.selectedCandidate = null;
  state.candidates = [];
  state.resultScopes = [];
  state.selectedScope = null;
  state.currentJurisdiction = null;
  const isVote = mode === 'vote';
  const isRun = mode === 'run';
  const isRegister = mode === 'register';
  const isResults = mode === 'results';
  const isAdmin = mode === 'admin';

  modeVoteBtn.classList.toggle('active', isVote);
  modeRunBtn.classList.toggle('active', isRun);
  modeResultsBtn.classList.toggle('active', isResults);
  modeResultsBtn.textContent = isAdmin
    ? (state.labels.admin || 'Election Setup')
    : (state.labels.results || 'Results');
  modeResultsBtn.classList.toggle('hidden', !(isResults || isAdmin));
  modeVoteBtn.style.display = (isRegister || isAdmin) ? 'none' : 'inline-block';
  modeRunBtn.style.display = (isRegister || isAdmin) ? 'none' : 'inline-block';
  if (isResults || isAdmin) {
    modeVoteBtn.style.display = 'none';
    modeRunBtn.style.display = 'none';
  }

  candidateCard.style.display = (isVote || isResults) ? 'block' : 'none';
  submitBtn.textContent = isVote
    ? state.labels.submit_vote
    : (isAdmin ? (state.labels.submit_admin || 'Start Election') : state.labels.submit_run);
  submitBtn.classList.toggle('hidden', isRegister || isResults ? true : false);
  registerActions.classList.toggle('hidden', !isRegister);
  scopeRow.classList.toggle('hidden', !isResults);

  candidateLabel.textContent = isResults
    ? (state.labels.results || 'Results')
    : (state.labels.select_candidate || 'Select Candidate');

  if (isRegister) {
    positionList.innerHTML = '';
    const line = document.createElement('div');
    line.textContent = state.labels.register_prompt || 'Register to vote';
    positionList.appendChild(line);
    candidateList.innerHTML = '';
    return;
  }

  if (isAdmin) {
    candidateList.innerHTML = '';
    return renderPositions();
  }

  renderPositions();
  if (isResults) {
    renderResultsRows([]);
  } else {
    renderCandidates();
  }
};

const renderPositions = () => {
  positionList.innerHTML = '';
  for (const item of state.positions) {
    const btn = document.createElement('button');
    const adminActive = state.adminSelectedPositions.has(item.name);
    btn.className = `item ${(state.selectedPosition?.name === item.name || adminActive) ? 'active' : ''}`;
    btn.textContent = `${item.name} (${item.jurisdiction})`;
    btn.onclick = async () => {
      if (state.mode === 'admin') {
        if (state.adminSelectedPositions.has(item.name)) {
          state.adminSelectedPositions.delete(item.name);
        } else {
          state.adminSelectedPositions.add(item.name);
        }
        renderPositions();
        return;
      }

      await selectPosition(item);
    };
    positionList.appendChild(btn);
  }

  if (state.mode === 'vote' && state.autoSelectFirst && !state.selectedPosition && state.positions.length > 0) {
    state.autoSelectFirst = false;
    selectPosition(state.positions[0]);
  }

  if (state.mode === 'results' && !state.selectedPosition && state.positions.length > 0) {
    selectPosition(state.positions[0]);
  }
};

const renderCandidates = () => {
  candidateList.innerHTML = '';
  if (state.mode !== 'vote') {
    return;
  }

  if (!state.selectedPosition) {
    const line = document.createElement('div');
    line.textContent = state.labels.select_position;
    candidateList.appendChild(line);
    return;
  }

  if (!state.candidates.length) {
    const line = document.createElement('div');
    line.textContent = state.labels.no_candidates;
    candidateList.appendChild(line);
    return;
  }

  for (const item of state.candidates) {
    const btn = document.createElement('button');
    btn.className = `item ${state.selectedCandidate?.cid === item.cid ? 'active' : ''}`;
    btn.textContent = item.name;
    btn.onclick = () => {
      state.selectedCandidate = item;
      renderCandidates();
    };
    candidateList.appendChild(btn);
  }
};

const closePanel = async () => {
  await post('close');
  showStatus('');
  hideApp();
};

submitBtn.onclick = async () => {
  if (state.mode === 'admin') {
    if (state.adminSelectedPositions.size === 0) {
      showStatus(state.labels.admin_select_required || 'Please select at least one office');
      return;
    }

    await post('applyElectionSetup', { positions: Array.from(state.adminSelectedPositions) });
    hideApp();
    return;
  }

  if (!state.selectedPosition) {
    return;
  }

  if (state.mode === 'run') {
    await post('runForOffice', { position: state.selectedPosition.name });
    hideApp();
    return;
  }

  if (!state.selectedCandidate) {
    return;
  }

  await post('castVote', {
    position: state.selectedPosition.name,
    jurisdiction: state.selectedPosition.jurisdiction.toLowerCase(),
    candidateid: state.selectedCandidate.cid,
    ballotid: state.selectedCandidate.ballotID,
  });

  hideApp();
};

registerBtn.onclick = async () => {
  const result = await post('registerToVote');
  if (result?.ok) {
    showStatus(result.message || 'Registration successful');
    state.autoSelectFirst = true;
    setTimeout(() => {
      setMode('vote');
    }, 700);
    return;
  }

  await setMode('vote');
};

closeBtn.onclick = closePanel;
modeVoteBtn.onclick = () => setMode('vote');
modeRunBtn.onclick = () => setMode('run');
modeResultsBtn.onclick = () => setMode('results');

scopeSelect.onchange = async () => {
  if (!scopeSelect.value) {
    return;
  }

  state.selectedScope = JSON.parse(scopeSelect.value);
  await loadResultsForScope(state.selectedScope);
};

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && state.open) {
    closePanel();
  }
});

window.addEventListener('message', (event) => {
  const data = event.data;
  if (!data) {
    return;
  }

  if (data.action === 'close') {
    showStatus('');
    hideApp();
    return;
  }

  if (data.action !== 'open') {
    return;
  }

  resourceName = data.resourceName || resourceName;
  state.city = data.city;
  state.region = data.region;
  state.gameState = data.state;
  state.labels = data.labels || {};
  state.positions = data.positions || [];
  state.autoSelectFirst = data.autoSelectFirst === true;
  state.mode = data.mode || 'vote';
  state.adminSelectedPositions = new Set(data.selectedPositions || []);

  showStatus('');
  titleEl.textContent = state.labels.title || 'Election Booth';
  const subtitleCity = data.subtitleCity || state.city || '-';
  const subtitleRegion = data.subtitleRegion || state.region || '-';
  const subtitleState = data.subtitleState || state.gameState || '-';
  subtitleEl.textContent = `${subtitleCity} - ${subtitleRegion} (${subtitleState})`;
  closeBtn.textContent = state.labels.close || 'Close';
  modeVoteBtn.textContent = state.labels.vote || 'Vote';
  modeRunBtn.textContent = state.labels.run || 'Run for Office';
  modeResultsBtn.textContent = state.labels.results || 'Results';
  registerBtn.textContent = state.labels.register_now || 'Register now';
  positionLabel.textContent = state.labels.select_position || 'Select Office';
  candidateLabel.textContent = state.labels.select_candidate || 'Select Candidate';
  scopeLabel.textContent = state.labels.select_scope || 'Select Scope';

  showApp();
  setMode(state.mode);
});
