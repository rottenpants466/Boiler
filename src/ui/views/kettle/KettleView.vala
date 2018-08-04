using Gtk;
using GLib;
using Granite;
using Granite.Widgets;
using Boiler.UI.Windows;

using Boiler.Bluetooth;
using Boiler.Devices.Abstract;

namespace Boiler.UI.Views.Kettle
{
	public class KettleView: BaseView
	{
		public BTKettle kettle { get; construct; }

		private ToggleButton boil_btn;
		private Label temp_label;
		private Label boil_label;

		private Label address_label;
		private Spinner spinner;

		private CssProvider? temp_style = new CssProvider();
		private CssProvider? btn_temp_style = new CssProvider();
		private bool updating = false;
		private int old_temp = -1;

		public KettleView(BTKettle kettle)
		{
			Object(kettle: kettle);
		}

		construct
		{
			var title_label = new Label(kettle.bt_device.name);
			title_label.get_style_context().add_class(Granite.STYLE_CLASS_PRIMARY_LABEL);
			title_label.hexpand = true;

			address_label = new Label(kettle.bt_device.address);
			address_label.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
			address_label.get_style_context().add_class("small");
			address_label.hexpand = true;

			temp_label = new Label("");
			boil_label = new Label("");
			boil_label.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);

			var btn_content = new Box(Orientation.VERTICAL, 4);
			btn_content.valign = btn_content.halign = Align.CENTER;
			btn_content.add(temp_label);
			btn_content.add(new Image.from_icon_name("system-shutdown-symbolic", IconSize.DND));
			btn_content.add(boil_label);

			boil_btn = new ToggleButton();
			boil_btn.add(btn_content);
			boil_btn.get_style_context().add_class("boil-button");
			boil_btn.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			boil_btn.get_style_context().add_class("circular");
			boil_btn.set_size_request(96, 96);
			boil_btn.margin_top = 16;
			boil_btn.halign = Align.CENTER;

			var icon = kettle.bt_device.icon ?? "bluetooth";
			if(kettle.bt_device.name in Devices.WITH_ICONS) icon = "device-" + kettle.bt_device.name;

			var image = new Image.from_icon_name(icon, IconSize.DND);
			image.halign = Align.START;

			spinner = new Spinner();
			spinner.margin = 8;
			spinner.set_size_request(16, 16);
			spinner.halign = Align.END;

			attach(title_label, 0, 0, 3, 1);
			attach(address_label, 0, 1, 3, 1);
			attach(image, 0, 0, 1, 2);
			attach(spinner, 2, 0, 1, 2);
			attach(boil_btn, 1, 2, 1, 1);

			kettle.notify["is-connected"].connect(update);
			kettle.notify["temperature"].connect(update);
			kettle.notify["is-boiling"].connect(update);
			kettle.notify["status"].connect(update);

			update();

			boil_btn.toggled.connect(() => {
				spinner.active = true;
				boil_btn.sensitive = false;
				if(boil_btn.active && !kettle.is_boiling)
				{
					kettle.start_boiling();
				}
				else if(!boil_btn.active && kettle.is_boiling)
				{
					kettle.stop_boiling();
				}
			});

			show_all();
		}

		private void update()
		{
			Idle.add(() => {
				if(updating) return Source.REMOVE;
				updating = true;

				lock(kettle)
				{
					boil_btn.sensitive = kettle.is_connected;
					spinner.active = !kettle.is_connected;
					spinner.queue_draw();

					boil_btn.active = kettle.is_connected && kettle.is_boiling;
					temp_label.label = kettle.temperature > 0 ? @"$(kettle.temperature) \u2103" : "";
					boil_label.label = kettle.is_boiling ? "Stop" : "Start";
					address_label.tooltip_text = kettle.status;

					if(window == null || window.get_toplevel() == null)
					{
						updating = false;
						return Source.REMOVE;
					}

					var ctx = window.get_toplevel().get_style_context();

					if(kettle.is_connected) ctx.add_class("connected"); else ctx.remove_class("connected");
					if(kettle.is_boiling) ctx.add_class("boiling"); else ctx.remove_class("boiling");

					if(kettle.temperature != old_temp)
					{
						var temp = int.max(0, kettle.temperature - 30);

						var alpha = float.min((float) temp / 100, 100).to_string().replace(",", ".");
						var css = @".kettle.connected{background-image: linear-gradient(to top, alpha(@boiler_hot, $(alpha)), alpha(@boiler_hot, 0) $(temp + 30)%)}";
						temp_style.load_from_data(css);

						var btn_css = @".kettle.connected .boil-button{background-image: linear-gradient(to top, alpha(black, 0.1) $(temp + 30)%, transparent $(temp + 30)%, transparent)}";
						btn_temp_style.load_from_data(btn_css);
					}
					old_temp = kettle.temperature;

					window.get_toplevel().queue_draw();
					boil_btn.queue_draw();
				}

				updating = false;

				return Source.REMOVE;
			});
		}

		public override void on_show()
		{
			var ctx = window.get_toplevel().get_style_context();
			ctx.add_class("kettle");
			ctx.add_provider(temp_style, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
			boil_btn.get_style_context().add_provider(btn_temp_style, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
			update();
		}
	}
}