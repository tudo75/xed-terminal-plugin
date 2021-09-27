/*
 * xed-encodings-dialog.h
 * This file is part of xed
 *
 * Copyright (C) 2003-2005 Paolo Maggi 
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, 
 * Boston, MA 02110-1301, USA. 
 */

/*
 * Modified by the xed Team, 2003-2005. See the AUTHORS file for a 
 * list of people on the xed Team.  
 * See the ChangeLog files for a list of changes. 
 *
 * $Id$
 */

#ifndef __XED_ENCODINGS_DIALOG_H__
#define __XED_ENCODINGS_DIALOG_H__

#include <gtk/gtk.h>

G_BEGIN_DECLS

/*
 * Type checking and casting macros
 */
#define XED_TYPE_ENCODINGS_DIALOG              (xed_encodings_dialog_get_type())
#define XED_ENCODINGS_DIALOG(obj)              (G_TYPE_CHECK_INSTANCE_CAST((obj), XED_TYPE_ENCODINGS_DIALOG, XedEncodingsDialog))
#define XED_ENCODINGS_DIALOG_CONST(obj)        (G_TYPE_CHECK_INSTANCE_CAST((obj), XED_TYPE_ENCODINGS_DIALOG, XedEncodingsDialog const))
#define XED_ENCODINGS_DIALOG_CLASS(klass)      (G_TYPE_CHECK_CLASS_CAST((klass), XED_TYPE_ENCODINGS_DIALOG, XedEncodingsDialogClass))
#define XED_IS_ENCODINGS_DIALOG(obj)           (G_TYPE_CHECK_INSTANCE_TYPE((obj), XED_TYPE_ENCODINGS_DIALOG))
#define XED_IS_ENCODINGS_DIALOG_CLASS(klass)   (G_TYPE_CHECK_CLASS_TYPE ((klass), XED_TYPE_ENCODINGS_DIALOG))
#define XED_ENCODINGS_DIALOG_GET_CLASS(obj)    (G_TYPE_INSTANCE_GET_CLASS((obj), XED_TYPE_ENCODINGS_DIALOG, XedEncodingsDialogClass))


/* Private structure type */
typedef struct _XedEncodingsDialogPrivate XedEncodingsDialogPrivate;

/*
 * Main object structure
 */
typedef struct _XedEncodingsDialog XedEncodingsDialog;

struct _XedEncodingsDialog 
{
	GtkDialog dialog;

	/*< private > */
	XedEncodingsDialogPrivate *priv;
};

/*
 * Class definition
 */
typedef struct _XedEncodingsDialogClass XedEncodingsDialogClass;

struct _XedEncodingsDialogClass 
{
	GtkDialogClass parent_class;
};

/*
 * Public methods
 */
GType		 xed_encodings_dialog_get_type	(void) G_GNUC_CONST;

GtkWidget	*xed_encodings_dialog_new		(void);

G_END_DECLS

#endif /* __XED_ENCODINGS_DIALOG_H__ */

