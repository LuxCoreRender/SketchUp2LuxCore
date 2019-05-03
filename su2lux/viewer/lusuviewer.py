import getopt
import os
import sys
from array import *
from decimal import Decimal
from functools import partial
from time import localtime, strftime

import numpy as np
from PySide2.QtCore import *
from PySide2.QtGui import *
from PySide2.QtWidgets import *

import pyluxcore

from ui_mainwindowsu import Ui_MainWindow

class MainWindow(QMainWindow):

    def __init__(self, inputfile, outputfile,propfile,  parent=None):
        super(MainWindow, self).__init__()
        self.ui = Ui_MainWindow()
        self.ui.setupUi(self)
        print('Input file is "', inputfile)
        print('Output file is "', outputfile)
        print('Output file is "', propfile)
        fi = QFileInfo(outputfile)
        self.ext = fi.completeSuffix()
        print(self.ext)
        self.cfgFileName = outputfile
        self.lastpath = os.path.dirname(inputfile)       
        self.filmWidth, self.filmHeight = 512, 512
        self.scaleFactor = 0.0
      # ui stuff
        self.setWindowTitle('Sketchup2LuxCore')
        self.center()
        self.eximage = propfile
                
        pyluxcore.ClearFileNameResolverPaths()
        pyluxcore.AddFileNameResolverPath(".")
        pyluxcore.AddFileNameResolverPath(self.lastpath)
        self.ui.saveBtn.clicked.connect(self.save_image)
        self.ui.stopBtn.clicked.connect(self.render_stop)
        self.ui.stopBtn.setEnabled(False)

        self.ui.pauBtn.clicked.connect(self.render_pause)
        self.ui.pauBtn.setEnabled(False)
        self.ui.renBtn.clicked.connect(self.render_image)
        self.ui.renBtn.setEnabled(True)
        self.ui.inBtn.clicked.connect(self.zoomIn)
        self.ui.outBtn.clicked.connect(self.zoomOut)
        self.ui.actionLoad_File.triggered.connect(self.load_file)
        self.ui.actionSave_Scene.triggered.connect(self.save_file)
        self.ui.actionSave_Image.triggered.connect(self.save_image)
        self.ui.actionZoom_In_25_Ctrl.triggered.connect(self.zoomIn)
        self.ui.actionZoom_In_25_Ctrl_2.triggered.connect(self.zoomOut)
        self.ui.actionNormal_Size_Ctrl_s.triggered.connect(self.normalSize)
        self.ui.fitToWindowAct.triggered.connect(self.fitToWindow)

        self.fromSu = False
        self.paused = False
        self.halt = 0
        self.shalt = 0
        self.timer = QBasicTimer()
        self.path = ""
        self.allocateImageBuffers()
        if self.cfgFileName != "":
            self.fromSu = True

            self.load_stuff()

    def zoomIn(self):
        self.scaleImage(1.25)

    def zoomOut(self):
        self.scaleImage(0.8)

    def normalSize(self):
        self.ui.renderView.adjustSize()
        self.scaleFactor = 1.0

    def fitToWindow(self):
        fitToWindow = self.ui.fitToWindowAct.isChecked()
        self.ui.scrollArea.setWidgetResizable(fitToWindow)
        if not fitToWindow:
            self.normalSize()

    def scaleImage(self, factor):
        self.scaleFactor *= factor
        self.ui.renderView.resize(self.scaleFactor * self.ui.renderView.pixmap().size())

        self.adjustScrollBar(self.ui.scrollArea.horizontalScrollBar(), factor)
        self.adjustScrollBar(self.ui.scrollArea.verticalScrollBar(), factor)

        self.scaleFactor < 3.0
        self.scaleFactor > 0.333

    def adjustScrollBar(self, scrollBar, factor):
        scrollBar.setValue(int(factor * scrollBar.value()
                                + ((factor - 1) * scrollBar.pageStep()/2)))
    def load_file(self):
        self.session = None
        self.config = None
        self.scene = None
        self.timer.stop()
        self.path, _ = QFileDialog.getOpenFileName(
            self, "Open File", "", "*.cfg *.lxs *.bcf")
        fi = QFileInfo(self.path)
        self.ext = fi.completeSuffix()
        print(self.ext)
        self.cfgFileName = self.path
        self.lastpath = os.path.dirname(self.path)
        pyluxcore.ClearFileNameResolverPaths()
        pyluxcore.AddFileNameResolverPath(".")
        pyluxcore.AddFileNameResolverPath(self.lastpath)
        self.load_stuff()   

    def load_stuff(self):
        self.session = None
        self.config = None
        self.scene = None
        self.ui.renBtn.setEnabled(True)
        self.ui.stopBtn.setEnabled(False)
        self.ui.pauBtn.setEnabled(False)
        self.ui.renderView.clear()
        cmdLineProp = pyluxcore.Properties()
        self.configProps = pyluxcore.Properties()
        self.sceneProps = pyluxcore.Properties()
        print(self.ext)
        print(self.cfgFileName)
        if (self.ext == "lxs"):
            os.chdir(self.lastpath)
            pyluxcore.ParseLXS(
            self.cfgFileName, self.configProps, self.sceneProps)
            self.configProps.Set(cmdLineProp)
            self.scene = pyluxcore.Scene(
                self.configProps.Get("images.scale", [1.0]).GetFloat())
            self.scene.Parse(self.sceneProps)
            self.config = pyluxcore.RenderConfig(
                self.configProps, self.scene)

            self.setup()
            return
        elif (self.ext == "cfg"):
            os.chdir(self.lastpath)
            print(self.cfgFileName)
            self.configProps = pyluxcore.Properties(self.cfgFileName)
            self.scene = pyluxcore.Scene(self.configProps.Get("scene.file").GetString())
            self.sceneProps = self.scene.ToProperties()
            self.cameraPos = self.sceneProps.Get("scene.camera.lookat.orig").GetFloats()
            self.config = pyluxcore.RenderConfig(self.configProps, self.scene)
            self.setup()

        elif(self.ext == "bcf"):
            os.chdir(self.lastpath)
            self.config = pyluxcore.RenderConfig(self.cfgFileName)
            self.configProps.Parse(cmdLineProp);
            self.setup()

    def setup(self):
        self.session = pyluxcore.RenderSession(self.config)
        self.selectedFilmChannel = pyluxcore.FilmOutputType.RGB_IMAGEPIPELINE
        self.filmWidth, self.filmHeight = self.config.GetFilmSize()[:2]
        self.allocateImageBuffers()
        self.resize(  self.filmWidth +60, self.filmHeight+130)
        print("File loaded")
        self.update()
       
        if self.fromSu == True:
            if self.eximage !="":
                self.configProps.SetFromString("""
                film.outputs.0.filename = "{image}"
                """.format(image = self.eximage))
            self.render_image()
    def save_file(self):
        path = QFileDialog().getSaveFileName(self, u"Save as", (""), "*.cfg")

        fileName = path[0]
        if not fileName == "":
            if not fileName.endswith('cfg'):
                fileName = fileName + '.cfg'
            print(fileName)
            fi = QFileInfo(fileName)
            getName = fi.fileName()
            getDir = os.path.dirname(fileName)
            print (getName)
            print(getDir)

            
        self.configProps.Set(pyluxcore.Property("renderengine.type", ["FILESAVER"]))
        print("scene saved")
        self.configProps.SetFromString("""
        filesaver.format = "TXT"
        filesaver.renderengine.type = "PATHCPU"
        filesaver.directory = {dirt} 
        filesaver.filename ={cfgName}
        """.format(dirt= "\""+ getDir +"/\"", cfgName = getName))           
        self.render_image()

    def render_image(self):
        self.ui.renderView.clear()
        self.scaleFactor = 1.0
        if not self.ui.fitToWindowAct.isChecked():
            self.ui.renderView.adjustSize()
        self.update()
        try:
            self.halt = self.configProps.Get("batch.halttime").GetInt()
            print(self.halt)

        except:
            print("no halttime set")
        try:
            self.shalt = self.configProps.Get("batch.haltspp").GetInt()
            print(self.shalt)

        except:
            print("no samples set")
        self.config = pyluxcore.RenderConfig(self.configProps, self.scene)
        self.session = pyluxcore.RenderSession(self.config)
        self.session.Start()
        self.timer.start(500, self)
        self.ui.renBtn.setEnabled(False)
        self.ui.stopBtn.setEnabled(True)
        self.ui.pauBtn.setEnabled(True)

    def center(self):
        screen = self.ui.centralwidget.geometry()
        size = self.ui.centralwidget.geometry()

    def allocateImageBuffers(self):
        self.imageBufferFloat = array(
            'f', [0.0] * (self.filmWidth * self.filmHeight * 3))
        self.imageBufferUChar = array(
            'b', [0] * (self.filmWidth * self.filmHeight * 4))

    def render_stop(self):
        self.ui.renBtn.setEnabled(True)
        self.ui.stopBtn.setEnabled(False)
        self.ui.pauBtn.setEnabled(False)
        self.timer.stop()
        #self.session.Stop()
        self.session = None
        self.config = None

    def render_pause(self):
        if self.paused == False:
            self.session.Pause()
            self.timer.stop()
            self.paused = True
        else:
            self.session.Resume()
            self.timer.start(500, self)
            self.paused = False

    def save_image(self):
        self.session.GetFilm().Save()
        print("Image saved")        

    def timerEvent(self, event):
        if event.timerId() == self.timer.timerId():
            # Update statistics
            self.session.UpdateStats()
            stats = self.session.GetStats()
            self.ui.statusbar.showMessage("[Elapsed time: %3.1fsec][Samples %4d][Avg. samples/sec % 3.2fM on %.1fK tris]" % (
                stats.Get("stats.renderengine.time").GetFloat(),
                stats.Get("stats.renderengine.pass").GetInt(),
                (stats.Get("stats.renderengine.total.samplesec").GetFloat() / 1000000.0),
                (stats.Get("stats.dataset.trianglecount").GetFloat() / 1000.0)))
            # Update the image
            self.session.GetFilm().GetOutputFloat(
                self.selectedFilmChannel, self.imageBufferFloat)
            pyluxcore.ConvertFilmChannelOutput_3xFloat_To_4xUChar(self.filmWidth, self.filmHeight, self.imageBufferFloat, self.imageBufferUChar,
                                                                  False if self.selectedFilmChannel == pyluxcore.FilmOutputType.RGB_IMAGEPIPELINE else True)

            # halt render
            if self.halt > 0 and self.halt == int(stats.Get("stats.renderengine.time").GetFloat()):
                
                if self.eximage !="":
                    self.session.GetFilm().Save()
                    self.close()

                self.render_stop()

            if self.shalt > 0 and self.shalt == int(stats.Get("stats.renderengine.pass").GetFloat()):
                self.render_stop()

            # image
            image = QImage(self.imageBufferUChar, self.filmWidth,
                           self.filmHeight, QImage.Format_RGB32)
            self.ui.renderView.setPixmap(QPixmap.fromImage(image))           
            
        else:
            QFrame.timerEvent(self, event)
    #python.exe c:/Users/nige/Desktop/LuxStudio/lusuviewer.py -d "C:/Users/nige/AppData/Roaming/LuxRender/" -f "chapel _BlueGlass.lxs" -D "film.outputs.0.filename = \"C:/Users/nige/AppData/Roaming/LuxRender/chapel_BlueGlass.png\""
   #python.exe c:/Users/nige/Desktop/LuxStudio/lusuviewer.py -d "C:/Users/nige/AppData/Roaming/LuxRender/" -f "chapel _BlueGlass.lxs" -D \"chapel_BlueGlass.png\""
   
    def closeEvent(self, event):
        self.timer.stop()
        self.session.Stop()
        self.session = None
        self.config = None
        self.scene = None
        event.accept()
def LogHandler(msg):
    print("[%s]%s" % (strftime("%Y-%m-%d %H:%M:%S", localtime()), msg))

def main(argv):
    inputfile = ''
    outputfile = ''
    propfile =''
    try:
        opts, args = getopt.getopt(argv, "hd:f:D:", ["ifile=", "ofile=","dfil=" ])
    except getopt.GetoptError:
        print('test.py -d <inputfile> -f <outputfile> -D <propfile>')
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            print('test.py -d <inputfile> -f <outputfile> -D <propfile>')
            sys.exit()
        elif opt in ("-d", "--ifile"):
            inputfile = arg
        elif opt in ("-f", "--ofile"):
            outputfile = arg
        elif opt in ("-D", "--dfile"):
            propfile = arg

    print("LuxCore %s" % pyluxcore.Version())
    pyluxcore.Init(LogHandler)
    app = QApplication.instance()
    if app is None:
        app = QApplication(sys.argv)
    window = MainWindow(inputfile, outputfile,propfile)
    if propfile == "":
        window.show()
    app.exec_()


if __name__ == '__main__':
    main(sys.argv[1:])
