let currentJob = null;
let selectedJob = null;
let confirmCallback = null;

function show(el) { el.classList.remove('hidden'); }
function hide(el) { el.classList.add('hidden'); }
function isVisible(el) { return !el.classList.contains('hidden'); }

// ==================== DRAG FUNCTIONALITY ====================
function makeDraggable(element, handle) {
    let pos1 = 0, pos2 = 0, pos3 = 0, pos4 = 0;
    let isDragging = false;

    handle.onmousedown = dragMouseDown;

    function dragMouseDown(e) {
        if (e.target.closest('.circle-btn')) return;
        e.preventDefault();
        pos3 = e.clientX;
        pos4 = e.clientY;
        isDragging = true;

        document.onmouseup = closeDragElement;
        document.onmousemove = elementDrag;
    }

    function elementDrag(e) {
        if (!isDragging) return;
        e.preventDefault();

        pos1 = pos3 - e.clientX;
        pos2 = pos4 - e.clientY;
        pos3 = e.clientX;
        pos4 = e.clientY;

        const stage = element.parentElement;
        element.style.position = 'relative';

        let newTop = element.offsetTop - pos2;
        let newLeft = element.offsetLeft - pos1;

        const maxX = Math.max(0, (stage ? stage.offsetWidth : window.innerWidth) - element.offsetWidth);
        const maxY = Math.max(0, (stage ? stage.offsetHeight : window.innerHeight) - element.offsetHeight);

        newTop = Math.max(-200, Math.min(newTop, maxY + 200));
        newLeft = Math.max(-200, Math.min(newLeft, maxX + 200));

        element.style.top = newTop + 'px';
        element.style.left = newLeft + 'px';
    }

    function closeDragElement() {
        isDragging = false;
        document.onmouseup = null;
        document.onmousemove = null;
    }
}

function resetPanelPosition(el) {
    el.style.position = '';
    el.style.top = '';
    el.style.left = '';
}

// Initialize draggable elements
document.addEventListener('DOMContentLoaded', function() {
    const mainContainer = document.getElementById('mainContainer');
    const dragHandle = document.getElementById('dragHandle');
    const choiceContainer = document.getElementById('choiceContainer');
    const choiceDragHandle = document.getElementById('choiceDragHandle');

    makeDraggable(mainContainer, dragHandle);
    makeDraggable(choiceContainer, choiceDragHandle);
});

// ==================== TOASTS ====================
function showToast(type, label, message) {
    const stack = document.getElementById('toasts');
    const toast = document.createElement('div');
    toast.className = 'toast toast-' + (type || 'info');
    toast.innerHTML = '<span class="toast-label"></span><div class="toast-msg"></div>';
    toast.querySelector('.toast-label').textContent = label || type || 'Notice';
    toast.querySelector('.toast-msg').textContent = message || '';
    stack.appendChild(toast);

    setTimeout(function() {
        toast.classList.add('toast-out');
        setTimeout(function() { toast.remove(); }, 260);
    }, 3200);
}

// ==================== UI UPDATES ====================
function updateDutyStatus(onDuty) {
    const dutyIcon = document.getElementById('dutyIcon');
    const dutyStatus = document.getElementById('dutyStatus');
    const dutyIndicator = document.getElementById('dutyIndicator');

    if (onDuty) {
        dutyIcon.innerHTML = '<i class="fa-solid fa-toggle-on"></i>';
        dutyStatus.textContent = 'On Duty';
        dutyStatus.className = 'row-desc duty-status on-duty';
        dutyIndicator.className = 'duty-indicator on-duty';
    } else {
        dutyIcon.innerHTML = '<i class="fa-solid fa-toggle-off"></i>';
        dutyStatus.textContent = 'Off Duty';
        dutyStatus.className = 'row-desc duty-status off-duty';
        dutyIndicator.className = 'duty-indicator off-duty';
    }
}

function updateCapacity(count, max) {
    const safeMax = Math.max(1, parseInt(max, 10) || 6);
    const safeCount = Math.max(0, parseInt(count, 10) || 0);
    const pct = Math.min(100, (safeCount / safeMax) * 100);

    document.getElementById('jobCount').textContent = safeCount;
    document.getElementById('maxJobs').textContent = safeMax;
    document.getElementById('maxJobsFooter').textContent = safeMax;

    const fill = document.getElementById('capacityFill');
    fill.style.width = pct + '%';
    fill.classList.remove('stat-good', 'stat-warn', 'stat-bad');
    if (pct >= 85) fill.classList.add('stat-bad');
    else if (pct >= 60) fill.classList.add('stat-warn');
    else fill.classList.add('stat-good');
}

function createJobCard(job, isCurrentJob) {
    const card = document.createElement('div');
    card.className = 'row-card job-card' + (isCurrentJob ? ' current-job disabled' : '');
    card.dataset.job = job.job;
    card.dataset.jobLabel = job.jobLabel;
    card.dataset.grade = job.grade;

    const iconBadge = document.createElement('div');
    iconBadge.className = 'icon-badge';
    const icon = document.createElement('i');
    icon.className = job.icon || 'fa-solid fa-briefcase';
    iconBadge.appendChild(icon);

    const rowMain = document.createElement('div');
    rowMain.className = 'row-main';

    const title = document.createElement('div');
    title.className = 'row-title';
    title.textContent = job.jobLabel;

    const gradeDesc = document.createElement('div');
    gradeDesc.className = 'row-desc';
    const gradeEm = document.createElement('i');
    gradeEm.textContent = `Grade: ${job.gradeLabel} [${job.grade}]`;
    gradeDesc.appendChild(gradeEm);

    const salaryDesc = document.createElement('div');
    salaryDesc.className = 'row-desc job-salary';
    salaryDesc.textContent = `Salary: $${job.salary}`;

    rowMain.appendChild(title);
    rowMain.appendChild(gradeDesc);
    rowMain.appendChild(salaryDesc);

    card.appendChild(iconBadge);
    card.appendChild(rowMain);

    if (isCurrentJob) {
        const pill = document.createElement('span');
        pill.className = 'pill';
        pill.textContent = 'Current';
        card.appendChild(pill);
    } else {
        const arrow = document.createElement('div');
        arrow.className = 'row-arrow';
        arrow.innerHTML = '<i class="fa-solid fa-chevron-right"></i>';
        card.appendChild(arrow);

        card.addEventListener('click', function() {
            openChoiceMenu(job);
        });
    }

    return card;
}

function renderJobs(jobs, currentJobName) {
    const container = document.getElementById('jobsContainer');
    container.innerHTML = '';

    if (!jobs || jobs.length === 0) {
        container.innerHTML =
            '<div class="no-jobs">' +
                '<div class="no-jobs-icon"><i class="fa-solid fa-briefcase"></i></div>' +
                '<div class="no-jobs-text">No Jobs Found</div>' +
                '<div class="no-jobs-subtext"><i>You haven\'t registered any jobs yet.</i></div>' +
            '</div>';
        const maxEl = document.getElementById('maxJobs');
        updateCapacity(0, maxEl ? maxEl.textContent : 6);
        return;
    }

    jobs.forEach((job, index) => {
        const isCurrentJob = job.job === currentJobName;
        const card = createJobCard(job, isCurrentJob);
        card.style.animationDelay = (index * 0.05) + 's';
        container.appendChild(card);
    });

    const maxEl = document.getElementById('maxJobs');
    updateCapacity(jobs.length, maxEl ? maxEl.textContent : 6);
}

// ==================== CHOICE MENU ====================
function openChoiceMenu(job) {
    selectedJob = job;

    hide(document.getElementById('mainContainer'));
    const choice = document.getElementById('choiceContainer');
    show(choice);
    resetPanelPosition(choice);
    document.getElementById('choiceJobName').textContent = job.jobLabel;
}

function closeChoiceMenu() {
    hide(document.getElementById('choiceContainer'));
    const main = document.getElementById('mainContainer');
    show(main);
    selectedJob = null;
}

// ==================== CONFIRM MODAL ====================
function showConfirm(title, text, callback) {
    confirmCallback = callback;
    document.getElementById('confirmTitle').textContent = title;
    document.getElementById('confirmText').textContent = text;
    show(document.getElementById('confirmModal'));
}

function hideConfirm() {
    hide(document.getElementById('confirmModal'));
    confirmCallback = null;
}

// ==================== EVENT LISTENERS ====================
document.getElementById('closeBtn').addEventListener('click', function() {
    closeUI();
});

document.getElementById('choiceCloseBtn').addEventListener('click', function() {
    closeUI();
});

document.getElementById('backBtn').addEventListener('click', function() {
    closeChoiceMenu();
});

document.getElementById('dutyToggle').addEventListener('click', function() {
    fetch(`https://${GetParentResourceName()}/toggleDuty`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
});

document.getElementById('switchJobBtn').addEventListener('click', function() {
    if (!selectedJob) return;

    showConfirm(
        'Switch Job?',
        `Are you sure you want to switch to ${selectedJob.jobLabel}?`,
        function() {
            fetch(`https://${GetParentResourceName()}/switchJob`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ job: selectedJob.job })
            });
            hideConfirm();
            closeChoiceMenu();
        }
    );
});

document.getElementById('deleteJobBtn').addEventListener('click', function() {
    if (!selectedJob) return;

    showConfirm(
        'Delete Job?',
        `Are you sure you want to remove ${selectedJob.jobLabel} from your jobs? This cannot be undone.`,
        function() {
            fetch(`https://${GetParentResourceName()}/deleteJob`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ job: selectedJob.job })
            });
            hideConfirm();
            closeChoiceMenu();
        }
    );
});

document.getElementById('confirmYes').addEventListener('click', function() {
    if (confirmCallback) {
        confirmCallback();
    }
});

document.getElementById('confirmNo').addEventListener('click', function() {
    hideConfirm();
});

// Close on escape key
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        if (isVisible(document.getElementById('confirmModal'))) {
            hideConfirm();
        } else if (isVisible(document.getElementById('choiceContainer'))) {
            closeChoiceMenu();
        } else {
            closeUI();
        }
    }
});

// ==================== NUI CALLBACKS ====================
function openUI() {
    show(document.getElementById('app'));
    show(document.getElementById('mainContainer'));
    hide(document.getElementById('choiceContainer'));
    hide(document.getElementById('confirmModal'));
    resetPanelPosition(document.getElementById('mainContainer'));
}

function closeUI() {
    hide(document.getElementById('mainContainer'));
    hide(document.getElementById('choiceContainer'));
    hideConfirm();
    hide(document.getElementById('app'));

    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === 'open') {
        openUI();

        updateDutyStatus(data.onDuty);
        document.getElementById('maxJobs').textContent = data.maxJobs || 6;
        document.getElementById('maxJobsFooter').textContent = data.maxJobs || 6;
        renderJobs(data.jobs, data.currentJob);
        currentJob = data.currentJob;
    }

    if (data.action === 'close') {
        hide(document.getElementById('mainContainer'));
        hide(document.getElementById('choiceContainer'));
        hideConfirm();
        hide(document.getElementById('app'));
    }

    if (data.action === 'updateDuty') {
        updateDutyStatus(data.onDuty);
    }

    if (data.action === 'refreshJobs') {
        renderJobs(data.jobs, data.currentJob);
        currentJob = data.currentJob;
    }

    if (data.action === 'notify') {
        showToast(data.type || 'info', data.label || 'Notice', data.message || '');
    }
});
