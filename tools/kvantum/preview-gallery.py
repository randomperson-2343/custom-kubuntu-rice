#!/usr/bin/env python3
"""Widget gallery for the Matrix95 Kvantum theme (PyQt5, offscreen).

Usage (python3.12 on Ubuntu 24.04 has the PyQt5 bindings):
  XDG_CONFIG_HOME=<dir containing Kvantum/kvantum.kvconfig + the rendered theme> \
  QT_QPA_PLATFORM=offscreen /usr/bin/python3.12 preview-gallery.py out.png
Needs: qt5-style-kvantum python3-pyqt5.  The Kvantum theme format is shared
with the Qt6 build (qt6-style-kvantum), so this previews what Plasma gets.
"""
import sys
from PyQt5 import QtCore, QtGui, QtWidgets as W

out = sys.argv[1] if len(sys.argv) > 1 else "gallery.png"
scale = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0

QtCore.QCoreApplication.setAttribute(QtCore.Qt.AA_EnableHighDpiScaling)
app = W.QApplication(sys.argv[:1] + ["-style", "kvantum"])
f = app.font()
f.setFamily("DejaVu Sans Mono")
f.setPixelSize(13)
app.setFont(f)
print("style:", app.style().objectName())


def box(title, layout_cls=W.QVBoxLayout):
    g = W.QGroupBox(title)
    l = layout_cls(g)
    return g, l


win = W.QMainWindow()
win.setWindowTitle("Matrix95")

# menubar
mb = win.menuBar()
m1 = mb.addMenu("&File")
m1.addAction("&New")
m1.addAction("&Open...")
a = m1.addAction("Chec&ked item")
a.setCheckable(True)
a.setChecked(True)
m1.addSeparator()
dis = m1.addAction("Disabled item")
dis.setEnabled(False)
sub = m1.addMenu("&Recent")
sub.addAction("one.txt")
m1.addAction("E&xit")
mb.addMenu("&Edit").addAction("Copy")
mb.addMenu("&View").addAction("Zoom")
mb.addMenu("&Help").addAction("About")

# toolbar
tb = win.addToolBar("Main")
st = app.style()
for i, name in enumerate(["New", "Open", "Save"]):
    act = tb.addAction(st.standardIcon(W.QStyle.SP_FileIcon), name)
tb.addSeparator()
tg = tb.addAction(st.standardIcon(W.QStyle.SP_DirIcon), "Toggled")
tg.setCheckable(True)
tg.setChecked(True)
tb.addSeparator()
tbtn = W.QToolButton()
tbtn.setText("Menu")
tbtn.setPopupMode(W.QToolButton.MenuButtonPopup)
mm = W.QMenu()
mm.addAction("x")
tbtn.setMenu(mm)
tb.addWidget(tbtn)

central = W.QWidget()
win.setCentralWidget(central)
grid = W.QGridLayout(central)

# --- buttons
g, l = box("Buttons")
b = W.QPushButton("OK")
b.setDefault(True)
l.addWidget(b)
l.addWidget(W.QPushButton("Cancel"))
d = W.QPushButton("Disabled")
d.setEnabled(False)
l.addWidget(d)
p = W.QPushButton("Pushed in")
p.setCheckable(True)
p.setChecked(True)
l.addWidget(p)
grid.addWidget(g, 0, 0)

# --- check / radio
g, l = box("Choices")
c1 = W.QCheckBox("Checked")
c1.setChecked(True)
l.addWidget(c1)
l.addWidget(W.QCheckBox("Unchecked"))
c3 = W.QCheckBox("Partial")
c3.setTristate(True)
c3.setCheckState(QtCore.Qt.PartiallyChecked)
l.addWidget(c3)
c4 = W.QCheckBox("Disabled on")
c4.setChecked(True)
c4.setEnabled(False)
l.addWidget(c4)
r1 = W.QRadioButton("Radio on")
r1.setChecked(True)
l.addWidget(r1)
l.addWidget(W.QRadioButton("Radio off"))
r3 = W.QRadioButton("Disabled")
r3.setEnabled(False)
l.addWidget(r3)
grid.addWidget(g, 1, 0)

# --- inputs
g, l = box("Inputs")
le = W.QLineEdit("Wake up, Neo...")
l.addWidget(le)
le2 = W.QLineEdit("disabled field")
le2.setEnabled(False)
l.addWidget(le2)
cb = W.QComboBox()
cb.addItems(["Follow the white rabbit", "Red pill", "Blue pill", "Another"])
l.addWidget(cb)
ce = W.QComboBox()
ce.setEditable(True)
ce.addItems(["Editable combo", "two"])
l.addWidget(ce)
sp = W.QSpinBox()
sp.setValue(42)
l.addWidget(sp)
ds = W.QDoubleSpinBox()
ds.setValue(3.14)
l.addWidget(ds)
grid.addWidget(g, 0, 1, 2, 1)

# --- progress / sliders
g, l = box("Progress, sliders")
pb = W.QProgressBar()
pb.setValue(37)
l.addWidget(pb)
pb2 = W.QProgressBar()
pb2.setValue(80)
pb2.setTextVisible(False)
l.addWidget(pb2)
s1 = W.QSlider(QtCore.Qt.Horizontal)
s1.setValue(40)
l.addWidget(s1)
s2 = W.QSlider(QtCore.Qt.Horizontal)
s2.setTickPosition(W.QSlider.TicksBelow)
s2.setTickInterval(10)
s2.setValue(70)
l.addWidget(s2)
hs = W.QScrollBar(QtCore.Qt.Horizontal)
hs.setRange(0, 100)
hs.setPageStep(30)
hs.setValue(20)
l.addWidget(hs)
grid.addWidget(g, 0, 2)

# --- tabs
tabs = W.QTabWidget()
t1 = W.QWidget()
tl = W.QVBoxLayout(t1)
tl.addWidget(W.QLabel("General page"))
tl.addWidget(W.QCheckBox("Option"))
tabs.addTab(t1, "General")
tabs.addTab(W.QLabel("Display"), "Display")
tabs.addTab(W.QLabel("Sound"), "Sound")
grid.addWidget(tabs, 1, 2)

# --- list with long content (vertical scrollbar) + tree
lst = W.QListWidget()
for i in range(60):
    lst.addItem(f"Item number {i:02d}")
lst.setCurrentRow(16)
grid.addWidget(lst, 0, 3, 2, 1)

tree = W.QTreeWidget()
tree.setHeaderLabels(["Name", "Size"])
root = W.QTreeWidgetItem(["System", "4 KB"])
for n in ("alpha", "beta", "gamma"):
    root.addChild(W.QTreeWidgetItem([n, "1 KB"]))
tree.addTopLevelItem(root)
root.setExpanded(True)
root2 = W.QTreeWidgetItem(["Users", "2 KB"])
root2.addChild(W.QTreeWidgetItem(["neo", "1 KB"]))
tree.addTopLevelItem(root2)
tree.setCurrentItem(root.child(1))
grid.addWidget(tree, 2, 0, 1, 2)

te = W.QTextEdit()
te.setPlainText("The Matrix has you.\nKnock, knock.")
grid.addWidget(te, 2, 2, 1, 2)

sb = win.statusBar()
sb.showMessage("Ready")

win.resize(int(980), int(640))
win.show()
app.processEvents()
lst.verticalScrollBar().setValue(14)
app.processEvents()
cb.setFocus()

# --- open-looking popups: a menu and the combo list
ps = []
mb.setActiveAction(m1.menuAction())
app.processEvents()
m1.setActiveAction(m1.actions()[1])
app.processEvents()
ps.append(m1)
cb.showPopup()
app.processEvents()
ps.append(cb.view().window())
W.QToolTip.showText(win.mapToGlobal(QtCore.QPoint(600, 600)), "Tooltip text", win)
app.processEvents()
for tw in app.topLevelWidgets():
    if tw.metaObject().className() == "QTipLabel" and tw.isVisible():
        ps.append(tw)

img = win.grab().toImage()
STRIP = 290
res = QtGui.QImage(img.width() + STRIP, img.height(), QtGui.QImage.Format_RGB32)
res.fill(QtGui.QColor(win.palette().color(QtGui.QPalette.Window)))
painter = QtGui.QPainter(res)
painter.drawImage(0, 0, img)
y = 12
for pw in ps:
    pm = pw.grab()
    print(type(pw).__name__, pm.size())
    painter.drawPixmap(QtCore.QPoint(img.width() + 12, y), pm)
    y += pm.height() + 14
painter.end()
res.save(out)
print("saved", out, res.width(), res.height())
