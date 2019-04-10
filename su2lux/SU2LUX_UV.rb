class SU2LUX_UV

	def initialize(lrs)
		@texturewriter = Sketchup.create_texture_writer
		@lrs = lrs
	end
	
	def get_selection_uvs(channel_number)
		model = Sketchup.active_model
		selection = model.selection
		tw = @texturewriter
		channel_uvs = []
		selection.each{ |entity|
			if entity.valid? and entity.is_a? Sketchup::Face
			
				mesh = entity.mesh 7
				material = entity.material
				material = entity.back_material if (material.nil?)
				if material
					mat_dir = true
					if (entity.material.nil?)
						mat_dir = false
					end
					if (material.materialType > 0)
						texture_size = Geom::Point3d.new(1, 1, 1)
						distorted = self.texture_distorted?(entity, mat_dir)
						for p in (1..mesh.count_points)
							if (distorted)
								vertex = mesh.point_at(p)
								handle = tw.load(entity, mat_dir)
								uvHelp = self.get_UVHelp(entity, mat_dir)
								uv = mat_dir ? uvHelp.get_front_UVQ(vertex) : uvHelp.get_back_UVQ(vertex)
							else
								uv = [mesh.uv_at(p, mat_dir).x/texture_size.x, mesh.uv_at(p, mat_dir).y/texture_size.y, mesh.uv_at(p, mat_dir).z/texture_size.z]
							end
							p "UV:#{"%.4f" %(uv.x)} #{"%.4f" %(-uv.y+1)}"
							channel_uvs.push(uv)
						end
					end
					luxmat = LuxrenderMaterial.new(material)
					luxmat.save_uv(channel_number, channel_uvs)
				end
			end
		}
	end # END get_selection_uvs

	##
	#
	##
	def texture_distorted?(e, mat_dir)
		distorted = false
		if e.valid? and e.is_a? Sketchup::Face
			uvHelp = self.get_UVHelp(e, mat_dir)
			for v in e.vertices
				p = v.position
				uvq = mat_dir ? uvHelp.get_front_UVQ(p) : uvHelp.get_back_UVQ(p)
				if ( uvq and (uvq.z.to_f - 1).abs > 1e-5)
					distorted = true
					break
				end
			end
		end
		return distorted
	end # END texture_distorted?

	##
	#
	##
	def get_UVHelp(e, mat_dir)
		uvHelp = e.get_UVHelper(mat_dir, !mat_dir, @texturewriter)
	end # END get_UVHelp
	
end