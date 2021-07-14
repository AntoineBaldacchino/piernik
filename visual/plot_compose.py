#!/usr/bin/python
# -*- coding: utf-8 -*-

import h5py
import matplotlib
import numpy as np
import pylab as P
from mpl_toolkits.axes_grid1 import AxesGrid
from mpl_toolkits.axes_grid1.inset_locator import inset_axes
import plot_utils as pu
import read_dataset as rd
import time as timer
# matplotlib.use('cairo')      # choose output format


def plot_axes(ax, ulen, l1, min1, max1, l2, min2, max2):
    ax.set_xlim(min1, max1)
    ax.set_ylim(min2, max2)
    ax.set_xlabel("%s [%s]" % (l1, pu.labelx()(ulen)))
    ax.set_ylabel("%s [%s]" % (l2, pu.labelx()(ulen)))
    return ax


def plot1d(refis, field, parts, equip, ncut, n1, n2):
    markers = [':', '--', '-']
    drawg, gcolor, smin, smax, zoom, center, ulen, output, labf, timep, autsc = equip
    vmin, vmax, sctype, symmin, cmap = field[1:]
    fig1d = P.figure(ncut + 2, figsize=(10, 8))

    ax = fig1d.add_subplot(111)
    P.xlim(zoom[1][ncut], zoom[2][ncut])
    if not autsc:
        P.ylim(vmin, vmax)

    for blks in refis:
        for bl in blks:
            binb, ble, bre, level, b1d = bl[1:]
            if binb[n1] and binb[n2]:
                if b1d != []:
                    bplot = pu.scale_plotarray(b1d[ncut], sctype, symmin)
                    dxh = (bre[ncut] - ble[ncut]) / float(len(b1d[ncut])) / 2.0
                    vax = np.linspace(ble[ncut] + dxh, bre[ncut] - dxh, len(b1d[ncut]))
                    ax.plot(vax, bplot, linestyle=markers[level], color='k')

    axis = "xyz"[ncut]
    P.ylabel(labf)
    P.xlabel("%s [%s]" % (axis, pu.labelx()(ulen)))
    P.title(timep)
    P.tight_layout()
    P.draw()
    out1d = output[1] + axis + '_' + output[2]
    fig1d.savefig(out1d, facecolor='white')
    print(out1d, "written to disk")
    P.clf()


def draw_plotcomponent(ax, refis, field, parts, equip, ncut, n1, n2):
    drawg, gcolor, smin, smax, zoom, center, ulen = equip[:-4]
    ag, ah = [], []
    if field[0] or drawg:
        if field[0]:
            vmin, vmax, sctype, symmin, cmap = field[1:]
        for blks in refis:
            for bl in blks:
                bxyz, binb, ble, bre, level = bl[:-1]
                if binb[ncut]:
                    if bxyz != []:
                        bplot = pu.scale_plotarray(bxyz[ncut], sctype, symmin)
                        ag = ax.imshow(bplot, origin="lower", extent=[ble[n1], bre[n1], ble[n2], bre[n2]], vmin=vmin, vmax=vmax, interpolation='nearest', cmap=cmap)
                    if drawg:
                        ax.plot([ble[n1], ble[n1], bre[n1], bre[n1], ble[n1]], [ble[n2], bre[n2], bre[n2], ble[n2], ble[n2]], '-', linewidth=0.5, alpha=0.1 * float(level + 1), color=gcolor[level], zorder=4)
    if parts[0]:
        pxyz, pm, nbins, pcolor, psize, player = parts[1:]
        if player[0] and player[ncut + 1] != '0':
            pmask = np.abs(pxyz[ncut] - center[ncut]) <= float(player[ncut + 1])
            pn1, pn2 = pxyz[n1][pmask], pxyz[n2][pmask]
            if nbins > 1:
                pmm = pm[pmask]
            else:
                pmm = pm
        else:
            pn1, pn2, pmm = pxyz[n1], pxyz[n2], pm
        ax, ah = draw_particles(ax, pn1, pn2, pmm, nbins, [smin[n1], smax[n1], smin[n2], smax[n2]], field[0], pcolor, psize)
    ax = plot_axes(ax, ulen, "xyz"[n1], zoom[1][n1], zoom[2][n1], "xyz"[n2], zoom[1][n2], zoom[2][n2])
    ax.set_xticks([center[n1]], minor=True)
    ax.set_yticks([center[n2]], minor=True)
    ax.tick_params(axis='x', which='minor', color='silver', bottom='on', top='on', width=2., length=6.)
    ax.tick_params(axis='y', which='minor', color='silver', left='on', right='on', width=2., length=6.)
    return ax, ag, ah


def draw_particles(ax, p1, p2, pm, nbins, ranges, drawd, pcolor, psize):
    if nbins > 1:
        ah = ax.hist2d(p1, p2, nbins, weights=pm, range=[ranges[0:2], ranges[2:4]], norm=matplotlib.colors.LogNorm(), cmap=pcolor)
        if not drawd:
            ax.set_facecolor('xkcd:black')
    else:
        ah = []
        if psize <= 0:
            psize = matplotlib.rcParams['lines.markersize']**2
        ax.scatter(p1, p2, c=pcolor, marker=".", s=psize)
    return ax, ah


def add_cbar(cbar_mode, grid, ab, fr, clab):
    if cbar_mode == 'none':
        axg = grid[1]
        pu.color_axes(axg, 'white')
        bar = inset_axes(axg, width='100%', height='100%', bbox_to_anchor=(fr, 0.0, 0.06, 1.0), bbox_transform=axg.transAxes, loc=2, borderpad=0)
        cbarh = P.colorbar(ab, cax=bar, format='%.1e', drawedges=False)
    else:
        bar = grid.cbar_axes[0]
        bar.axis["right"].toggle(all=True)
        cbarh = P.colorbar(ab, cax=bar, format='%.1e', drawedges=False)
        cbarh = P.colorbar(ab, cax=bar, format='%.1e', drawedges=False)
    cbarh.ax.set_ylabel(clab)
    if cbar_mode == 'none':
        cbarh.ax.yaxis.set_label_coords(-1.5, 0.5)


def plotcompose(pthfilen, var, output, options):
    axc, umin, umax, cmap, pcolor, player, psize, sctype, cu, center, drawg, drawd, drawu, drawa, drawp, nbins, uaxes, zoom, plotlevels, gridlist, gcolor = options
    drawh = drawp and nbins > 1
    h5f = h5py.File(pthfilen, 'r')
    time = h5f.attrs['time'][0]
    utim = h5f['dataset_units']['time_unit'].attrs['unit']
    ulenf = h5f['dataset_units']['length_unit'].attrs['unit']
    usc, ulen, uupd = pu.change_units(ulenf, uaxes)
    if drawd:
        uvar = h5f['dataset_units'][var].attrs['unit']
    if drawh:
        umass = h5f['dataset_units']['mass_unit'].attrs['unit']
    smin = h5f['simulation_parameters'].attrs['domain_left_edge']
    smax = h5f['simulation_parameters'].attrs['domain_right_edge']
    if uupd:
        smin = pu.list3_division(smin, usc)
        smax = pu.list3_division(smax, usc)
    cgcount = int(h5f['data'].attrs['cg_count'])
    glevels = h5f['grid_level'][:]
    maxglev = max(glevels)

    timep = "time = %5.2f %s" % (time, pu.labelx()(utim))
    print(timep)

    parts, field = [drawp, ], [drawd, ]

    if not cu:
        center = (smax[0] + smin[0]) / 2.0, (smax[1] + smin[1]) / 2.0, (smax[2] + smin[2]) / 2.0

    drawa, drawu = pu.choose_amr_or_uniform(drawa, drawu, drawd, drawg, drawp, maxglev, gridlist)
    plotlevels = pu.check_plotlevels(plotlevels, maxglev, drawa)
    if drawg:
        gcolor = pu.reorder_gridcolorlist(gcolor, maxglev, plotlevels)
    gridlist = pu.sanitize_gridlist(gridlist, cgcount)

    if drawp:
        pinfile, pxyz, pm = rd.collect_particles(h5f, drawh, center, player, uupd, usc, plotlevels, gridlist)
        parts = pinfile, pxyz, pm, nbins, pcolor, psize, player
        drawh = drawh and pinfile

    refis = []
    if drawd or drawg:
        extr = [], [], [], []
        if drawu:
            if len(plotlevels) > 1:
                print('For uniform grid plotting only the firs given level!')
            print('Plotting base level %s' % plotlevels[0])
            refis, extr = rd.reconstruct_uniform(h5f, var, plotlevels[0], gridlist, cu, center, smin, smax)

        if drawa or drawg:
            refis, extr = rd.collect_gridlevels(h5f, var, refis, extr, maxglev, plotlevels, gridlist, cgcount, center, usc, drawd)

        if refis == []:
            drawd = False
        else:
            if drawd:
                d2min, d2max, d3min, d3max = min(extr[0]), max(extr[1]), min(extr[2]), max(extr[3])
                vmin, vmax, symmin, autsc = pu.scale_manage(sctype, refis, umin, umax, d2min, d2max)

                print('3D data value range: ', d3min, d3max)
                print('Slices  value range: ', d2min, d2max)
                print('Plotted value range: ', vmin, vmax)
                field = drawd, vmin, vmax, sctype, symmin, cmap

    h5f.close()

    if not (parts[0] or drawd or drawg):
        print('No particles or levels to plot. Skipping.')
        return

    cbar_mode = pu.colorbar_mode(drawd, drawh)

    if not zoom[0]:
        zoom = False, smin, smax

    vlab = var + " [%s]" % pu.labelx()(uvar)
    equip = drawg, gcolor, smin, smax, zoom, center, ulen, output, vlab, timep, autsc

    p1x, p1y, p1z, p2xy, p2xz, p2yz, p2 = axc
    if p1x:
        plot1d(refis, field, parts, equip, 0, 1, 2)
    if p1y:
        plot1d(refis, field, parts, equip, 1, 0, 2)
    if p1z:
        plot1d(refis, field, parts, equip, 2, 0, 1)

    if p2:
        fig = P.figure(1, figsize=(10, 10.5))

        grid = AxesGrid(fig, 111, nrows_ncols=(2, 2), axes_pad=0.2, aspect=True, cbar_mode=cbar_mode, label_mode="L",)
        ag0, ag2, ag3 = [], [], []

        if p2yz:
            ax = grid[3]
            ax, ag3, ah = draw_plotcomponent(ax, refis, field, parts, equip, 0, 1, 2)

        if p2xz:
            ax = grid[2]
            ax, ag2, ah = draw_plotcomponent(ax, refis, field, parts, equip, 1, 0, 2)

        if p2xy:
            ax = grid[0]
            ax, ag0, ah = draw_plotcomponent(ax, refis, field, parts, equip, 2, 0, 1)
        ax.set_title(timep)

        if drawh:
            add_cbar(cbar_mode, grid, ah[3], 0.7, 'particle mass histogram' + " [%s]" % pu.labelx()(umass))

        if drawd:
            add_cbar(cbar_mode, grid, pu.take_nonempty([ag0, ag2, ag3]), 0.1, vlab)

        P.draw()
        P.savefig(output[0], facecolor='white')
        print(output[0], "written to disk")
        P.clf()
